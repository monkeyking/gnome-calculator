%{
/*  Copyright (c) 2004-2008 Sami Pietila
 *  Copyright (c) 2008-2009 Robert Ancell
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 *  02111-1307, USA.
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <errno.h>

#include "mp-equation-private.h"
#include "mp-equation-parser.h"
#include "mp-equation-lexer.h"

// fixme support x log x
// treat exp NAME exp as a function always and pass both arguments, i.e.
// can do mod using both and all others use $1 * NAME($3)

static void set_error(yyscan_t yyscanner, int error, const char *token)
{
    _mp_equation_get_extra(yyscanner)->error = error;
    if (token)
        _mp_equation_get_extra(yyscanner)->error_token = strdup(token);
}

static void set_result(yyscan_t yyscanner, const MPNumber *x)
{
    mp_set_from_mp(x, &(_mp_equation_get_extra(yyscanner))->ret);
}

static int get_variable(yyscan_t yyscanner, const char *name, MPNumber *z)
{
    if (!_mp_equation_get_extra(yyscanner)->get_variable(_mp_equation_get_extra(yyscanner), name, z)) {
        set_error(yyscanner, PARSER_ERR_UNKNOWN_VARIABLE, name);
        return 0;
    }
    
    return 1;
}

static void set_variable(yyscan_t yyscanner, const char *name, MPNumber *x)
{
    _mp_equation_get_extra(yyscanner)->set_variable(_mp_equation_get_extra(yyscanner), name, x);
}

static int get_function(yyscan_t yyscanner, const char *name, const MPNumber *x, MPNumber *z)
{
    if (!_mp_equation_get_extra(yyscanner)->get_function(_mp_equation_get_extra(yyscanner), name, x, z)) {
        set_error(yyscanner, PARSER_ERR_UNKNOWN_FUNCTION, name);
        return 0;
    }
    return 1;
}

static void do_not(yyscan_t yyscanner, const MPNumber *x, MPNumber *z)
{
    if (!mp_is_overflow(x, _mp_equation_get_extra(yyscanner)->options->wordlen)) {
        set_error(yyscanner, PARSER_ERR_OVERFLOW, NULL);
    }
    mp_not(x, _mp_equation_get_extra(yyscanner)->options->wordlen, z);
}

static void do_conversion(yyscan_t yyscanner, const MPNumber *x, const char *x_units, const char *z_units, MPNumber *z)
{
    void *data = _mp_equation_get_extra(yyscanner)->options->callback_data;

    if (_mp_equation_get_extra(yyscanner)->options->convert == NULL
        || !_mp_equation_get_extra(yyscanner)->options->convert(x, x_units, z_units, z, data)) {
        set_error(yyscanner, PARSER_ERR_UNKNOWN_CONVERSION, NULL);
    }
}

%}

%pure-parser
%name-prefix="_mp_equation_"
%locations
%parse-param {yyscan_t yyscanner}
%lex-param {yyscan_t yyscanner}

%union {
  MPNumber int_t;
  int integer;
  char *name;
}

%left <int_t> tNUMBER
%left UNARY_PLUS
%left tADD tSUBTRACT
%left tAND tOR tXOR tXNOR
%left tMULTIPLY tDIVIDE tMOD MULTIPLICATION
%left tNOT
%left tROOT tROOT3 tROOT4
%left <name> tVARIABLE
%right <integer> tSUBNUM tSUPNUM tNSUPNUM
%left BOOLEAN_OPERATOR
%left PERCENTAGE
%left UNARY_MINUS
%right '^' '!' '|'
%left tIN

%type <int_t> exp variable
%start statement

%%

statement:
  exp { set_result(yyscanner, &$1); }
| exp '=' { set_result(yyscanner, &$1); }
| tVARIABLE '=' exp {set_variable(yyscanner, $1, &$3); set_result(yyscanner, &$3); }
| tNUMBER tVARIABLE tIN tVARIABLE { MPNumber t; do_conversion(yyscanner, &$1, $2, $4, &t); set_result(yyscanner, &t); free($2); free($4); }
| tVARIABLE tIN tVARIABLE { MPNumber x, t; mp_set_from_integer(1, &x); do_conversion(yyscanner, &x, $1, $3, &t); set_result(yyscanner, &t); free($1); free($3); }
;

/* |x| gets confused and thinks = |x|(...||) */

exp:
  '(' exp ')' {mp_set_from_mp(&$2, &$$);}
| '|' exp '|' {mp_abs(&$2, &$$);}
| '|' tVARIABLE '|' {get_variable(yyscanner, $2, &$$); mp_abs(&$$, &$$); free($2);} /* FIXME: Shouldn't need this rule but doesn't parse without it... */
| '|' tNUMBER tVARIABLE '|' {get_variable(yyscanner, $3, &$$); mp_multiply(&$2, &$$, &$$); mp_abs(&$$, &$$); free($3);} /* FIXME: Shouldn't need this rule but doesn't parse without it... */
| exp '^' exp {mp_xpowy(&$1, &$3, &$$);}
| exp tSUPNUM {mp_xpowy_integer(&$1, $2, &$$);}
| exp tNSUPNUM {mp_xpowy_integer(&$1, $2, &$$);}
| exp '!' {mp_factorial(&$1, &$$);}
| variable {mp_set_from_mp(&$1, &$$);}
| tNUMBER variable %prec MULTIPLICATION {mp_multiply(&$1, &$2, &$$);}
| tSUBTRACT exp %prec UNARY_MINUS {mp_invert_sign(&$2, &$$);}
| tADD tNUMBER %prec UNARY_PLUS {mp_set_from_mp(&$2, &$$);}
| exp tDIVIDE exp {mp_divide(&$1, &$3, &$$);}
| exp tMOD exp {mp_modulus_divide(&$1, &$3, &$$);}
| exp tMULTIPLY exp {mp_multiply(&$1, &$3, &$$);}
| exp tADD exp '%' %prec PERCENTAGE {mp_add_integer(&$3, 100, &$3); mp_divide_integer(&$3, 100, &$3); mp_multiply(&$1, &$3, &$$);}
| exp tSUBTRACT exp '%' %prec PERCENTAGE {mp_add_integer(&$3, -100, &$3); mp_divide_integer(&$3, -100, &$3); mp_multiply(&$1, &$3, &$$);}
| exp tADD exp {mp_add(&$1, &$3, &$$);}
| exp tSUBTRACT exp {mp_subtract(&$1, &$3, &$$);}
| exp '%' {mp_divide_integer(&$1, 100, &$$);}
| tNOT exp {do_not(yyscanner, &$2, &$$);}
| exp tAND exp %prec BOOLEAN_OPERATOR {mp_and(&$1, &$3, &$$);}
| exp tOR exp %prec BOOLEAN_OPERATOR {mp_or(&$1, &$3, &$$);}
| exp tXOR exp %prec BOOLEAN_OPERATOR {mp_xor(&$1, &$3, &$$);}
| tNUMBER {mp_set_from_mp(&$1, &$$);}
;


variable:
  tVARIABLE exp {if (!get_function(yyscanner, $1, &$2, &$$)) YYABORT; free($1);}
| tVARIABLE tSUPNUM exp {if (!get_function(yyscanner, $1, &$3, &$$)) YYABORT; mp_xpowy_integer(&$$, $2, &$$); free($1);}
| tSUBNUM tROOT exp {mp_root(&$3, $1, &$$);}
| tROOT exp {mp_sqrt(&$2, &$$);}
| tROOT3 exp {mp_root(&$2, 3, &$$);}
| tROOT4 exp {mp_root(&$2, 4, &$$);}
| tVARIABLE {if (!get_variable(yyscanner, $1, &$$)) YYABORT; free($1);}
;

%%