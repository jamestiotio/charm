header {
//header
//Pass2:
// strip-mine MSA for loops
package jade;
}

{
//class preamble
import jade.JJ.J;
}

/** Java 1.3 AST Recognizer Grammar
 *
 * Author: (see java.g preamble)
 * Author: J. DeSouza
 *
 */
class JavaTreeParser2 extends TreeParser;

options {
	importVocab = Java;
    buildAST = true;
}

compilationUnit
	:	(p:packageDefinition)?
		(importDefinition)*
		(typeDefinition[p])*
        { if (p != null)
            J.tmp.pop();
        }
	;

packageDefinition
	:	#( PACKAGE_DEF i:identifier { J.tmp.push(J.pE(i)); })
	;

importDefinition
	:	#( IMPORT identifierStar )
	;

typeDefinition[AST parent]
	:	#(c:CLASS_DEF modifiers IDENT { J.tmp.push(#IDENT.getText()); } extendsClause implementsClause
            o:objBlock) { J.tmp.pop(); }
	|	#(INTERFACE_DEF modifiers IDENT extendsClause interfaceBlock )
	;

typeSpec
	:	#(TYPE typeSpecArray)
	;

typeSpecArray
	:	#( ARRAY_DECLARATOR typeSpecArray )
	|	type
	;

type:	identifier
	|	builtInType
	;

builtInType
    :   "void"
    |   "boolean"
    |   "byte"
    |   "char"
    |   "short"
    |   "int"
    |   "float"
    |   "long"
    |   "double"
    ;

modifiers
	:	#( MODIFIERS (modifier)* )
	;

modifier
    :   "private"
    |   "public"
    |   "protected"
    |   "static"
    |   "transient"
    |   "final"
    |   "abstract"
    |   "native"
    |   "threadsafe"
    |   "synchronized"
    |   "const"
    |   "volatile"
	|	"strictfp"
	|	"threaded"
 	|	"blocking"
	|	"readonly"
    ;

extendsClause
	:	#(EXTENDS_CLAUSE (identifier)* )
	;

implementsClause
	:	#(IMPLEMENTS_CLAUSE (identifier)* )
	;

interfaceBlock
	:	#(	OBJBLOCK
			(	methodDecl
			|	variableDef[true]
			)*
		)
	;

objBlock
	:	#(	OBJBLOCK
			(	ctorDef
			|	methodDef
			|	variableDef[true]
			|	typeDefinition[null]
			|	#(STATIC_INIT slist)
			|	#(INSTANCE_INIT slist)
			)*
		)
	;

ctorDef
	:	#(CTOR_DEF modifiers
            { J.startBlock(); }
            methodHead
            {J.tmp.push("");}
            ctorSList
            {
                J.endBlock();
                J.tmp.pop();
            })
	;

methodDecl
	:	#(METHOD_DEF modifiers typeSpec { J.startBlock(); } methodHead { J.endBlock(); })
	;

methodDef
	:	#(METHOD_DEF modifiers typeSpec
            { J.startBlock(); }
            mh:methodHead
            {
                J.tmp.push(new String(mh.getText()));
            }
            (slist)?
            {
                J.tmp.pop();
                J.endBlock();
            })
	;

variableDef[boolean classVarq]
	:	#(v:VARIABLE_DEF m:modifiers typeSpec 
            vd:variableDeclarator
            varInitializer
            {
                String varName = J.printVariableDeclarator(vd);
                if (!classVarq){
                    J.localStack.push(varName);
                    J.localStackShadow.push(v);
                }
            })
	;

parameterDef
	:	#(p:PARAMETER_DEF modifiers typeSpec i:IDENT {
                    J.localStack.push(i.getText());
                    J.localStackShadow.push(p);
            })
	;

objectinitializer
	:	#(INSTANCE_INIT slist)
	;

variableDeclarator
	:	IDENT
	|	LBRACK variableDeclarator
	;

varInitializer
	:	#(ASSIGN initializer)
	|
	;

initializer
	:	expression
	|	arrayInitializer
	;

arrayInitializer
	:	#(ARRAY_INIT (initializer)*)
	;

methodHead
	:	IDENT #( PARAMETERS (parameterDef)* ) (throwsClause)?
	;

throwsClause
	:	#( "throws" (identifier)* )
	;

identifier
	:	IDENT
	|	#( DOT identifier IDENT )
	;

identifierStar
	:	IDENT
	|	#( DOT identifier (STAR|IDENT) )
	;

ctorSList
	:	#( SLIST (ctorCall)? (stat)* )
	;

slist
	:	#( SLIST (stat)* )
	;

stat:	typeDefinition[null]
	|	variableDef[false]
	|	expression
	|	#(LABELED_STAT IDENT stat)
	|	#("if" expression stat (stat)? )
	|	#(	fo:"for"
            {
                if (J.isMSAAccessAnywhere(fo)) {
                    System.out.println("Found a loop which accesses an MSA");
                    String s = "{ int i = 0; for (i=0; i<10; i++) ; }";
                    AST ttt = J.parseString(s);
                    System.out.println(ttt.toStringTree());
                    System.out.println();

//                     AST _e1 = #(#[LITERAL_for,"for"],
//                             #(#[FOR_INIT,"FOR_INIT"], #[EXPR,"EXPR"]),
//                             #[FOR_CONDITION,"FOR_CONDITION"],
//                             #[FOR_ITERATOR,"FOR_ITERATOR"],
//                             #[EXPR,"EXPR"]);
//                     System.out.println(fo.toStringTree());
//                     System.out.println();
//                     System.out.println(_e1.toStringTree());
//                     System.out.println(_e1.toStringList());
//                     System.out.println();
                }
            }
			#(FOR_INIT (variableDef[false] | elist)?)
			#(FOR_CONDITION (expression)?)
			#(FOR_ITERATOR (elist)?)
			stat
		)
	|	#("while" expression stat)
	|	#("do" stat expression)
	|	#("break" (IDENT)? )
	|	#("continue" (IDENT)? )
	|	#("return" (expression)? )
	|	#("switch" expression (caseGroup)*)
	|	#("throw" expression)
	|	#("synchronized" expression stat)
	|	tryBlock
	|	{ J.startBlock(); } slist { J.endBlock(); } // nested SLIST
	|	EMPTY_STAT
	;

caseGroup
	:	#(CASE_GROUP (#("case" expression) | "default")+ slist)
	;

tryBlock
	:	#( "try" slist (handler)* (#("finally" slist))? )
	;

handler
	:	#( "catch" { J.startBlock(); } parameterDef slist { J.endBlock(); } )
	;

elist
	:	#( ELIST (expression)* )
	;

colonExpression
    :   #(COLON expression expression (expression)?)
    |   expression
    ;

expression
	:	#(EXPR expr)
	;

expr:	#(QUESTION expr expr expr)	// trinary operator
	|	#(ASSIGN expr expr)			// binary operators...
	|	#(PLUS_ASSIGN expr expr)
	|	#(MINUS_ASSIGN expr expr)
	|	#(STAR_ASSIGN expr expr)
	|	#(DIV_ASSIGN expr expr)
	|	#(MOD_ASSIGN expr expr)
	|	#(SR_ASSIGN expr expr)
	|	#(BSR_ASSIGN expr expr)
	|	#(SL_ASSIGN expr expr)
	|	#(BAND_ASSIGN expr expr)
	|	#(BXOR_ASSIGN expr expr)
	|	#(BOR_ASSIGN expr expr)
	|	#(LOR expr expr)
	|	#(LAND expr expr)
	|	#(BOR expr expr)
	|	#(BXOR expr expr)
	|	#(BAND expr expr)
	|	#(NOT_EQUAL expr expr)
	|	#(EQUAL expr expr)
	|	#(LT expr expr)
	|	#(GT expr expr)
	|	#(LE expr expr)
	|	#(GE expr expr)
	|	#(SL expr expr)
	|	#(SR expr expr)
	|	#(BSR expr expr)
	|	#(PLUS expr expr)
	|	#(MINUS expr expr)
	|	#(DIV expr expr)
	|	#(MOD expr expr)
	|	#(STAR expr expr)
	|	#(INC expr)
	|	#(DEC expr)
	|	#(POST_INC expr)
	|	#(POST_DEC expr)
	|	#(BNOT expr)
	|	#(LNOT expr)
	|	#("instanceof" expr expr)
	|	#(UNARY_MINUS expr)
	|	#(UNARY_PLUS expr)
	|	primaryExpression
	;

primaryExpression
    :   IDENT
    |   #(	DOT
			(	expr
				(	IDENT
				|	arrayIndex
				|	"this"
				|	"class"
				|	#( "new" IDENT elist )
				|   "super"
				)
			|	#(ARRAY_DECLARATOR typeSpecArray)
			|	builtInType ("class")?
			)
		)
	|	arrayIndex
	|	#(METHOD_CALL primaryExpression elist)
	|	#(TYPECAST typeSpec expr)
	|   newExpression
	|   constant
    |   "super"
    |   "true"
    |   "false"
    |   "this"
    |   "null"
	|	typeSpec // type name used with instanceof
	;

ctorCall
	:	#( CTOR_CALL elist )
	|	#( SUPER_CTOR_CALL
			(	elist
			|	primaryExpression elist
			)
		 )
	;

arrayIndex
	:	#(INDEX_OP primaryExpression colonExpression)
	;

constant
    :   NUM_INT
    |   CHAR_LITERAL
    |   STRING_LITERAL
    |   NUM_FLOAT
    |   NUM_DOUBLE
    |   NUM_LONG
    ;

newExpression
	:	#(	"new" type
			(	newArrayDeclarator (arrayInitializer)?
			|	elist (objBlock)?
			)
		)
			
	;

newArrayDeclarator
	:	#( ARRAY_DECLARATOR (newArrayDeclarator)? (expression)? )
	;
