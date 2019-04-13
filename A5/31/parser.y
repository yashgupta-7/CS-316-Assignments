%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	extern "C" void yyerror(const char *s);
	extern int yylex(void);
	extern int yylineno;
	Symbol_Table* global_sym_table = new Symbol_Table();
	Symbol_Table* local_sym_table = new Symbol_Table();
%}

%union {
	int integer_value;
	double double_value;
	std::string * string_value;
	list<Ast *> * ast_list;
	Ast * ast;
	Sequence_Ast * seq_ast;
	Symbol_Table * symbol_table;
	Symbol_Table_Entry * symbol_entry;
	Basic_Block * basic_block;
	Procedure * procedure;
	list<Symbol_Table_Entry *> * symbol_entry_list;
}

%token <integer_value> INTEGER_NUMBER
%token <double_value> DOUBLE_NUMBER
%token <string_value> NAME
%token BBNUM  RETURN  INTEGER  FLOAT  ASSIGN  VOID  UMINUS
%token WHILE IF DO ELSE
%token PRINT
%token EQUAL LESS_THAN GREATER_THAN LESS_THAN_EQUAL GREATER_THAN_EQUAL NOT_EQUAL
%token AND OR NOT

%type <symbol_entry_list> variable_list	declaration	variable_declaration variable_declaration_list optional_variable_declaration_list
%type <procedure> procedure_definition
%type <ast>	assignment_statement arith_expression
%type <ast> log_expression rel_expression iteration_statement statement selection_statement
%type <ast> sequence_statement
/*print*/
%type <ast> print_statement
%type <ast_list> statement_list



%right ASSIGN
%right '?' ':'
%left OR
%left AND
%left EQUAL NOT_EQUAL
%left LESS_THAN GREATER_THAN LESS_THAN_EQUAL GREATER_THAN_EQUAL
%left '+' '-'
%left '*' '/'
%right UMINUS
%right NOT
%nonassoc NOT_ELSE
%nonassoc ELSE

%start program

%%

program					:	global_variable_declaration_list procedure_definition
							{
								(*global_sym_table).set_table_scope(global);
								program_object.set_global_table(*global_sym_table);
								program_object.set_procedure($2, yylineno);
							}
							; 

procedure_definition	:	VOID NAME '(' ')'
                  	   		'{'
									local_variable_declaration_list statement_list
        	           		'}' 
							{	
								$$ = new Procedure(void_data_type,*$2, yylineno);
								(*local_sym_table).set_table_scope(local);
								(*$$).set_local_list((*local_sym_table));
								(*$$).set_ast_list(*($7));
							}
        	           		;


global_variable_declaration_list	: 	optional_variable_declaration_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
												(*it)->set_symbol_scope(global);
												Symbol_Table x;
												x.push_symbol(*it);
												x.set_table_scope(global);
												(*global_sym_table).append_list(x, (*it)->get_lineno());
											}
										}
										;

local_variable_declaration_list		: 	optional_variable_declaration_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
												(*it)->set_symbol_scope(local);
												Symbol_Table x;
												x.push_symbol(*it);
												x.set_table_scope(local);
												(*local_sym_table).append_list(x, (*it)->get_lineno());
											}
										}
										;
								
optional_variable_declaration_list	:	/* empty */ 
										{
											$$ = new list<Symbol_Table_Entry *>();
										}
										|	variable_declaration_list
										{
											$$ = $1;
										}
										;

variable_declaration_list			:	variable_declaration
										{
											$$ = $1;
										}
										|	variable_declaration_list variable_declaration
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*($1)).push_back(*it);
											}
											$$ = $1;
										}
										;

variable_declaration				:	declaration ';'
										{
											$$ = $1;
										}
										;

declaration							:	INTEGER variable_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*it)->set_data_type(int_data_type);
											}
											$$ = $2;
										}
										| FLOAT variable_list 
										{	
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*it)->set_data_type(double_data_type);
											}
											$$ = $2;
										}
                                        ;

variable_list                       :	NAME	
										{
											$$ = new list<Symbol_Table_Entry *>();
											*$1 = *$1 + "_";
											Symbol_Table_Entry* a = new Symbol_Table_Entry(*$1, int_data_type,yylineno);
											(*$$).push_back(a);
										}
										| variable_list ',' NAME
										{
											*$3 = *$3 + "_";
											Symbol_Table_Entry* b = new Symbol_Table_Entry(*$3, int_data_type,yylineno);
											(*$1).push_back(b); /* TODO: Clarify from the TA */
											$$ = $1;
										}
										;


statement_list	        :	/* empty */ 
							{
								$$ = new list<Ast *>();
							}
							|	statement_list sequence_statement
							{
								(*$1).push_back($2);
								$$ = $1;
							}
							;


statement 				:	assignment_statement
							{
								$$ = $1;
							}
							|	iteration_statement  /*while, do-while*/
							{
								$$ = $1;
							}
							|	selection_statement  /*if then else*/
							{
								$$ = $1;
							}
							/*print*/
							|	print_statement
							{
								$$ = $1;
							}
							;


sequence_statement		:	'{' statement_list '}'
							{
								if((*$2).empty()) 	/*body empty */
								{
									yyerror("cs316: Error: Block of statements cannot be empty");
									exit(1);
								}
			
								Sequence_Ast* temp = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
									temp->ast_push_back(*it);
								}
								$$ = temp;
							}
							|
							statement
							{
								$$ = $1;
							}
							;

iteration_statement		:	WHILE '(' log_expression ')' sequence_statement
							{
								$$ = new Iteration_Statement_Ast($3, $5, yylineno, 0); 	/*last arg is bool do_form */
							}
							|	DO sequence_statement WHILE '(' log_expression ')' ';'
							{
								$$ = new Iteration_Statement_Ast($5, $2, yylineno, 1); 	/*last arg is bool do_form */	
							}
							;

selection_statement		:	IF '(' log_expression ')' sequence_statement %prec NOT_ELSE
							{
								$$ = new Selection_Statement_Ast($3, $5, NULL, yylineno);
							}
							|	IF '(' log_expression ')' sequence_statement ELSE sequence_statement
							{
								$$ = new Selection_Statement_Ast($3, $5, $7, yylineno);
							}
							;

log_expression			:	log_expression AND log_expression
							{
								$$ = new Logical_Expr_Ast($1, _logical_and, $3, yylineno);
								(*$$).check_ast();
							}
							|	log_expression OR log_expression
							{
								$$ = new Logical_Expr_Ast($1, _logical_or, $3, yylineno);
								(*$$).check_ast();
							}
							|	NOT log_expression
							{
								$$ = new Logical_Expr_Ast(NULL, _logical_not, $2, yylineno);
								(*$$).check_ast();
							}
							|	rel_expression
							{
								$$ = $1;
								(*$$).check_ast();
							}
							|	'(' log_expression ')'
							{
								$$ = $2;
							}
							;

rel_expression			:	arith_expression EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, equalto, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression NOT_EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, not_equalto, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression LESS_THAN arith_expression
							{
								$$ = new Relational_Expr_Ast($1, less_than, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression LESS_THAN_EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, less_equalto, $3, yylineno);
								(*$$).check_ast();
							}	
							|	arith_expression GREATER_THAN arith_expression
							{
								$$ = new Relational_Expr_Ast($1, greater_than, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression GREATER_THAN_EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, greater_equalto, $3, yylineno);
								(*$$).check_ast();
							}
							;



assignment_statement	:	NAME ASSIGN arith_expression ';'
				
							{
								*$1 = *$1 + "_";
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*$1)){ 
									Ast* lhs1 = new Name_Ast(*$1, (*local_sym_table).get_symbol_table_entry(*$1), yylineno);
									$$ = new Assignment_Ast(lhs1,$3,yylineno);
									(*$$).check_ast();
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$1)){
									Ast* lhs2 = new Name_Ast(*$1, (*global_sym_table).get_symbol_table_entry(*$1), yylineno);
									$$ = new Assignment_Ast(lhs2,$3,yylineno);
									(*$$).check_ast();
								}
								else{
									yyerror("cs316: Error: Variable has not been declared");
									exit(1);
								}
							}
							;

print_statement			:	PRINT NAME ';'
							{
								*$2 = *$2 + "_";
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*$2)){ 
									Ast* var = new Name_Ast(*$2, (*local_sym_table).get_symbol_table_entry(*$2), yylineno);
									$$ = new Print_Ast(var, yylineno);
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$2)){
									Ast* var = new Name_Ast(*$2, (*global_sym_table).get_symbol_table_entry(*$2), yylineno);
									$$ = new Print_Ast(var, yylineno);
								}
								else{
									yyerror("cs316: Error: Variable has not been declared");
									exit(1);
								}
							}

arith_expression		: 	INTEGER_NUMBER	
							{
								$$ = new Number_Ast<int>($1, int_data_type, yylineno);
							}
							| DOUBLE_NUMBER 
							{
								$$ = new Number_Ast<double>($1, double_data_type, yylineno);
							}
							| NAME
							{
								*$1 = *$1 + "_";
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*($1))){
									$$ = new Name_Ast(*$1, (*local_sym_table).get_symbol_table_entry(*$1), yylineno);
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$1)){
									$$ = new Name_Ast(*$1, (*global_sym_table).get_symbol_table_entry(*$1), yylineno);
								}
								else{
									yyerror("cs316: Error : Variable has not been declared");
									exit(1);
								}
							}
							| arith_expression '+' arith_expression
							{
								$$ = new Plus_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| arith_expression '-' arith_expression
							{
								$$ = new Minus_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| arith_expression '*' arith_expression
							{
								$$ = new Mult_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| arith_expression '/' arith_expression
							{
								$$ = new Divide_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| '-' arith_expression %prec UMINUS
							{
								$$ = new UMinus_Ast($2,NULL,yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$2).get_data_type());
							}
							|	log_expression '?' arith_expression ':' arith_expression	/*ternary operator*/
							{
								$$ = new Conditional_Expression_Ast($1, $3, $5, yylineno);
								(*$1).check_ast();
								(*$$).check_ast();

							}
							| '('arith_expression')'
							{
								$$ = $2;
							}
							;


%%