
/*  $Header$
 *
 *  Copyright (C) 2004-2007 Sami Pietila
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

#ifndef FUNCTIONS_H
#define FUNCTIONS_H

#include "calctool.h"
#include "extern.h"

void do_factorial(int *, int *);
void exp_append(char *text);

struct exprm_state *get_state(void);
void new_state(void);
void perform_undo(void);
void perform_redo(void);
void clear_undo_history(void);
int usable_num(int MPnum[MP_SIZE]);

#endif /*FUNCTIONS_H*/