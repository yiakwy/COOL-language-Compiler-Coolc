/*
 *  The scanner definition for COOL.
 *  The codes template from stanford and Lei (yiak.wy@gmail) implements all the recognition with 100% tests passes. 
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

#include <string.h>
#include <stdio.h>
/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;
int str_len=0;
int contains_null=0;
int too_long=0;
char *error_msg=NULL;

#undef INCR_STR
#define INCR_STR(buf, el) \
	if (str_len >= MAX_STR_CONST-1) { \
		too_long = 1; \
		string_buf_ptr = string_buf; \
		str_len = 0; \
	} \
	*buf++ = el; \
	str_len++;
	

#undef CLR_STR
#define CLR_STR() \
	string_buf_ptr = string_buf; \
	str_len = 0; \
	too_long = 0; \
	contains_null = 0;

// comments
int no_open_sign=0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

/*
 * identifiers
 */
DIGIT [0-9]
ALPHA [a-zA-Z]
ID 	 	[a-zA-Z_][a-zA-Z0-9_]*
TypeID 		[A-Z][a-zA-Z0-9_]*
ObjectID 	[a-z][a-zA-Z0-9_]*

integer {DIGIT}+

/*
 * types
 */
string \"(\\.|[^\\\"\b\t\n\f\o(EOF)])*\"

/*
 * punctuations
 */
NEW_EXPR ;
COMMA ,
EOF <<EOF>>

short_comments --
open "(*"
close "*)"

open_str \"
close_str \"

DARROR		=>

%x str
%x comments
%x short_comment END
%option stack

%%
{integer} {
	cool_yylval.symbol = inttable.add_string(yytext);
	return INT_CONST;
}

 /*
  * Short comment
  */
-- 			yy_push_state(short_comment);
<short_comment><<EOF>> 	yy_push_state(END);
<END>{

	.+ {
		yy_pop_state();
		cool_yylval.error_msg="EOF in comment";
		BEGIN(INITIAL);
		return ERROR;
	}
	<<EOF>>         yy_pop_state();BEGIN(INITIAL);yyterminate();

}

<short_comment>[^\n]+	
<short_comment>\n 	yy_pop_state();BEGIN(INITIAL);curr_lineno++;

 /*
  *  Nested comments
  */
{close} {
	cool_yylval.error_msg = "Unmatched *)";
	return ERROR;
}

{open} {
	//printf("nested comments\n");
	//printf("+no_open_sign: %d\n", no_open_sign+1);
	++no_open_sign;
	BEGIN(comments);
}


<comments>{close} {
	if(--no_open_sign==0){
		BEGIN(INITIAL);
	}
	//printf("-no_open_sign: %d\n", no_open_sign);
}
<comments>{open} 	no_open_sign++;//printf("+no_open_sign: %d\n", no_open_sign);
<comments>\n 		++curr_lineno;
<comments><<EOF>> {
	//printf("mtched %s\n", yytext);
	cool_yylval.error_msg = "EOF in comment";
	BEGIN(INITIAL);
	return ERROR;
}
<comments>\*+[^*()\\\n]  	//printf("rule1 mtched %s\n", yytext);
<comments>[^\n(*\\]+ 	//printf("rule2 mtched %s\n", yytext); 	
<comments>\\[(*]?
<comments>[(*]		

 /*
  *  The multiple-character operators
  */

=>	{ return DARROW; }
\<=	{ return LE; }
\<-	{ return ASSIGN; }
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class) 	return CLASS;
(?i:else) 	return ELSE;
(?i:fi) 	return FI;
(?i:if) 	return IF;
(?i:in) 	return IN;
(?i:inherits) 	return INHERITS;
(?i:let) 	return LET;
(?i:loop) 	return LOOP;
(?i:pool)	return POOL;
(?i:then) 	return THEN;
(?i:while) 	return WHILE;
(?i:case) 	return CASE;
(?i:esac) 	return ESAC;
(?i:of)		return OF;
(?i:new) 	return NEW;
(?i:isvoid) 	return ISVOID;
(?i:not) 	return NOT;

t(?i:rue) {
	cool_yylval.boolean = true;
	return BOOL_CONST;
}

f(?i:alse) {
	cool_yylval.boolean = false;
	return BOOL_CONST;
} 

 /*
  * white space, punctuation
  */
\n {
	curr_lineno++;
}


\0   {
	cool_yylval.error_msg = "\0";
	return ERROR;
}
\000 {
	cool_yylval.error_msg = "\000";
	return ERROR;
}

"|"  |
"]"  |
"["  |
"`"  |
"?"  |
>  |
&  |
"^"  |
"%"  |
"$"  |
#  |
!  |
\\ |
_ {
	cool_yylval.error_msg = yytext;
	return ERROR;
}

[ ]+ 
[\b\f\r\t\v] 	

[;{}(,):@.+\-*/~<=]		return *yytext;		


 /*
  * Invalid methods
  */

\[0-7]{1,3} |
\\[0-7]{1,3} {
	//printf("mtched %s\n", yytext);

	int ret;
	(void*) sscanf(yytext+1, "%o", &ret);	

	if (ret > 0xff)
		cool_yylval.error_msg = "Out of bounds";
	else {
		cool_yylval.error_msg = yytext;
	}
	return ERROR;
}

  /*
   * Extended white space
   */


  /*
   *  String constants (C syntax)
   *  Escape sequence \c is accepted for all characters c. Except for 
   *  \n \t \b \f, the result is c.
   *
   */

{open_str} {
	//printf("first quota\n");
	CLR_STR()
	BEGIN(str);
}

<str>{close_str} {
	BEGIN(INITIAL);
	//printf("close quota\n");
	*string_buf_ptr = '\0';
	cool_yylval.symbol = stringtable.add_string(string_buf);
	if (contains_null == 1) {
		cool_yylval.error_msg = error_msg;
		return ERROR;
	}
	if (too_long == 1) {
		cool_yylval.error_msg = "String constant too long";
		return ERROR;
	}

	//printf("str_len: %d", str_len);
	return STR_CONST;
}

<str>\n {
	cool_yylval.error_msg = "Unterminated string constant";
	curr_lineno++;
	BEGIN(INITIAL);
	return ERROR;
}

<str>\0|\000 {
	//Another implementation method transfer state to another, but I am lazy ...
	error_msg = "String contains null character.";
	contains_null = 1;
}

<str>\\[0-7]{3} {
	int ret;
	//printf("<str> mtched: %s", yytext);
	(void) sscanf(yytext+1, "%o", &ret);
	
	if (ret > 0xff) {
		cool_yylval.error_msg="Out of bounds";
		BEGIN(INITIAL);
		return ERROR;
	}

	INCR_STR(string_buf_ptr, ret);
}

<str><<EOF>> {
	cool_yylval.error_msg = "EOF in string";
	BEGIN(INITIAL);
	return ERROR;
} 

<str>[ \t\r\b\f]+ {
	char* pos = yytext;
	while (*pos) {
		INCR_STR(string_buf_ptr, *pos++)
	}
}

<str>\\(.|\n) {
	//printf("mtched %s\n", yytext);
	char* pos = yytext;
	char* meta_c = pos + 1;
	switch (*meta_c) {
		case 'n':
			//printf("get \\n\n");
			INCR_STR(string_buf_ptr, '\n')
			break;
		case 't':
			//printf("get \\t\n");
			INCR_STR(string_buf_ptr, '\t')
			break;
		case 'f':
			INCR_STR(string_buf_ptr, '\f')
			break;
		case 'b':
			INCR_STR(string_buf_ptr, '\b')
			break;
		case '\0':
			error_msg = "String contains escaped null character.";
			contains_null = 1;
			break;
		case '\n':
			curr_lineno++;
		default:
			INCR_STR(string_buf_ptr, *meta_c);
	} 
}

<str>[^\\\n\0"]+ {
	//printf("matched2 str: %s\n", yytext);
	char* pos = yytext;
	
	while (*pos) {
		INCR_STR(string_buf_ptr, *pos++)
	}
}

 /*
  * Identifiers
  */

SELF_TYPE |
{TypeID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return TYPEID;
}

self |
{ObjectID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return OBJECTID;
}

 /*
  * octal string & other string capture
  */

[\000-\777] {
        //printf("octal val: %s\n", yytext);
        cool_yylval.error_msg = yytext;
        return ERROR;
}

[^a-zA-Z_"] {
        //printf("mtched %s\n", yytext);
        return *yytext;
}

%%
