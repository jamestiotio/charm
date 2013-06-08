#ifndef _sdag_H_
#define _sdag_H_

#include "pup.h"

namespace SDAG {
  struct Closure : public PUP::able {
    virtual void pup(PUP::er& p) = 0;
    PUPable_abstract(Closure);
  };
}

#include "charm++.h"
#include <vector>
#include <list>
#include <map>
#include <set>

#include <pup_stl.h>

namespace SDAG {
  struct TransportableBigSimLog : public Closure {
    void* log;
    TransportableBigSimLog() : log(0) { }
    TransportableBigSimLog(CkMigrateMessage*) : log(0) { }

    TransportableBigSimLog(void* log)
      : log(log) { }

    void pup(PUP::er& p) {
      if (p.isUnpacking()) log = 0;
    }
    PUPable_decl(TransportableBigSimLog);
  };

  struct MsgClosure : public Closure {
    void* msg;

    MsgClosure() : msg(0) { }
    MsgClosure(CkMigrateMessage*) : msg(0) { }

    MsgClosure(CkMessage* msg)
      : msg(msg) { }

    void pup(PUP::er& p) {
      bool isNull = !msg;
      p | isNull;
      if (!isNull) CkPupMessage(p, &msg);
    }
    PUPable_decl(MsgClosure);
  };

  class CCounter : public Closure {
  private:
    unsigned int count;
  public:
    CCounter() { }
    CCounter(CkMigrateMessage*) { }
    CCounter(int c) : count(c) { }
    CCounter(int first, int last, int stride) {
      count = ((last - first) / stride) + 1;
    }
    void decrement(void) { count--; }
    int isDone(void) { return (count == 0); }

    void pup(PUP::er& p) {
      p | count;
    }
    PUPable_decl(CCounter);
  };

  struct CSpeculator : public Closure {
    int speculationIndex;

    CSpeculator() { }
    CSpeculator(CkMigrateMessage*) { }

    CSpeculator(int speculationIndex_)
      : speculationIndex(speculationIndex_) { }

    void pup(PUP::er& p) {
      p | speculationIndex;
    }
    PUPable_decl(CSpeculator);
  };

  struct Continuation : public PUP::able {
    int whenID;
    std::vector<Closure*> closure;
    std::vector<int> entries, refnums;
    std::vector<int> anyEntries;
    int speculationIndex;

    Continuation() { }
    Continuation(CkMigrateMessage*) { }

    Continuation(int whenID)
      : whenID(whenID) { }

    void pup(PUP::er& p) {
      p | whenID;
      p | closure;
      p | entries;
      p | refnums;
      p | anyEntries;
      p | speculationIndex;
    }

    virtual ~Continuation() {
      for (int i = 0; i < closure.size(); i++) {
        delete closure[i];
      }
      closure.clear();
    }

    PUPable_decl(Continuation);
  };

  struct Buffer : public PUP::able {
    int entry, refnum;
    Closure* cl;

    Buffer(CkMigrateMessage*) { }

    Buffer(int entry, Closure* cl, int refnum)
      : entry(entry)
      , cl(cl)
      , refnum(refnum) { }

    void pup(PUP::er& p) {
      p | entry;
      p | refnum;
      bool hasCl = cl;
      p | hasCl;
      if (hasCl)
        p | cl;
    }

    virtual ~Buffer() {
      delete cl;
      cl = 0;
    }

    PUPable_decl(Buffer);
  };

  struct Dependency {
    std::vector<std::list<int> > entryToWhen;
    std::map<int, std::list<Continuation*> > whenToContinuation;

    // entry -> lst of buffers
    std::vector<std::list<Buffer*> > buffer;

    int curSpeculationIndex;

    void pup(PUP::er& p) {
      p | curSpeculationIndex;
      p | entryToWhen;
      p | buffer;
      p | whenToContinuation;
    }

    Dependency(int numEntries, int numWhens)
      : curSpeculationIndex(0)
      , buffer(numEntries)
      , entryToWhen(numEntries) { }

    void addDepends(int whenID, int entry) {
      entryToWhen[entry].push_back(whenID);
    }

    void reg(Continuation *c) {
      //printf("registering new continuation %p, whenID = %d\n", c, c->whenID);
      whenToContinuation[c->whenID].push_back(c);
    }

    void dereg(Continuation *c) {
      if (whenToContinuation.find(c->whenID) != whenToContinuation.end()) {
        std::list<Continuation*>& lst = whenToContinuation[c->whenID];
        lst.remove(c);
      } else {
        CkAbort("trying to deregister: continuation not found");
      }
    }

    Buffer* pushBuffer(int entry, Closure *cl, int refnum) {
      Buffer* buf = new Buffer(entry, cl, refnum);
      buffer[entry].push_back(buf);
      return buf;
    }

    Continuation *tryFindContinuation(int entry) {
      for (std::list<int>::iterator iter = entryToWhen[entry].begin();
           iter != entryToWhen[entry].end();
           ++iter) {
        int whenID = *iter;

        if (whenToContinuation.find(whenID) != whenToContinuation.end()) {
          for (std::list<Continuation*>::iterator iter2 = whenToContinuation[whenID].begin();
               iter2 != whenToContinuation[whenID].end();
               iter2++) {
            Continuation* c = *iter2;
            if (searchBufferedMatching(c)) {
              dereg(c);
              return c;
            }
          }
        }
      }
      //printf("no continuation found\n");
      return 0;
    }

    bool searchBufferedMatching(Continuation* t) {
      CkAssert(t->entries.size() == t->refnums.size());
      for (int i = 0; i < t->entries.size(); i++) {
        if (!tryFindMessage(t->entries[i], true, t->refnums[i], false)) {
          return false;
        }
      }
      for (int i = 0; i < t->anyEntries.size(); i++) {
        if (!tryFindMessage(t->anyEntries[i], false, 0, false)) {
          return false;
        }
      }
      return true;
    }

    Buffer* tryFindMessage(int entry, bool hasRef, int refnum, bool hasIgnore,
                           std::set<Buffer*> ignore = std::set<Buffer*>()) {
      if (buffer[entry].size() == 0) return 0;
      else {
        for (std::list<Buffer*>::iterator iter = buffer[entry].begin();
             iter != buffer[entry].end();
             ++iter) {
          if ((!hasRef || (*iter)->refnum == refnum) &&
              (!hasIgnore || ignore.find(*iter) == ignore.end()))
            return *iter;
        }
        return 0;
      }
    }

    Buffer* tryFindMessage(int entry) {
      if (buffer[entry].size() == 0) return 0;
      else {
        Buffer* buf = buffer[entry].front();
        //printf("found buffered message %p\n", buf);
        return buffer[entry].front();
      }
    }

    void removeMessage(Buffer *buf) {
      buffer[buf->entry].remove(buf);
    }

    int getAndIncrementSpeculationIndex() {
      return curSpeculationIndex++;
    }

    void removeAllSpeculationIndex(int speculationIndex) {
      for (std::map<int, std::list<Continuation*> >::iterator iter = whenToContinuation.begin();
           iter != whenToContinuation.end();
           ++iter) {
        std::list<Continuation*>& lst = iter->second;

        for (std::list<Continuation*>::iterator iter2 = lst.begin();
             iter2 != lst.end();
             ++iter2) {
          if ((*iter2)->speculationIndex == speculationIndex) {
            Continuation *cancelled = *iter2;
            iter2 = lst.erase(iter2);
            delete cancelled;
          }
        }
      }
    }
  };

  void registerPUPables();
}

#endif
