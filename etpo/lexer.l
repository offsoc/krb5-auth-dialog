%{
/*
 * Copyright (C) 2004 Red Hat, Inc.
 *
 * This is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Library General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */
#include "config.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <ftw.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <glib.h>
#include "grammar.h"
%}
%x QUOTED
%%
error_table|et		{ yylval.sval = g_strdup(yytext);
			  return ERROR_TABLE_START; };
end			{ return ERROR_TABLE_END; };
error_code|ec		{ yylval.sval = g_strdup(yytext);
			  return ERROR_CODE_START; };
,			{ return COMMA; };
\\\n			{ };
<INITIAL>[\r\n]		{ };
<INITIAL>[A-Za-z0-9_-]+	{ yylval.sval = g_strdup(yytext);
			  return TOKEN; };
<INITIAL>[ \t]		{ };
<INITIAL>\"		{ BEGIN(QUOTED);
			  yylval.sval = g_strdup("");
			  return QUOTE; };
<QUOTED>\"		{ BEGIN(INITIAL);
			  return QUOTE; };
<QUOTED>[^\"]+		{ yylval.sval = g_strdup(yytext);
			  return LITERAL; };
<QUOTED>\n		{ yylval.sval = g_strdup(yytext);
			  return LITERAL; };
<*>^#.*$		{ };
%%

/* Complete list of filenames, an iterator for that list, and the contents of
 * the current item. */
static GList *filenames = NULL, *filename = NULL;
const char *currentfile = NULL;

int
yyerror(void)
{
	g_print("Syntax error (%s).\n", currentfile);
	exit(1);
}

/* Callback for ftw().  Adds the filename being examined to the global list of
 * filenames. */
static int
fn(const char *file, const struct stat *st, int flag)
{
	int i;
	if (flag == FTW_F) {
		i = strlen(file);
		if ((i > 3) &&
		    (strncmp(file + strlen(file) - 3, ".et", 3) == 0)) {
			filenames = g_list_append(filenames, g_strdup(file));
		}
	}
	return 0;
}

/* Open the next filename in the list of files, if we have a list and we
 * haven't reached its end. */
int
yywrap(void)
{
	if ((filename != NULL) && (g_list_next(filename) != NULL)) {
		fclose(yyin);
		filename = g_list_next(filename);
		currentfile = filename->data;
		yyin = fopen(currentfile, "r");
		return 0;
	}
	return 1;
}

/* Spew forth a gettext .pot header. */
static void
header(void)
{
	const char *boilerplate = "const char *dummy = {\n";
	printf(boilerplate);
}

static void
tail(void)
{
	const char *boilerplate = "};\n";
	printf(boilerplate);
}

int
main(int argc, char **argv)
{
	int i;
	/* Call getopt.  We don't provide any options just now, but this lets
	 * us handle "--help" and "-h" queries simply. */
	while ((i = getopt(argc, argv, "")) != -1) {
		switch (i) {
		default:
			printf("Usage: etpo [directory ...]\n");
			return 2;
			break;
		}
	}
	/* Assume that each non-option argument is a directory. */
	for (i = optind; i < argc; i++) {
		if (ftw(argv[i], fn, 10) != 0) {
			perror("ftw");
			return 1;
		}
	}
	/* Spew out a header. */
	header();
	if (g_list_length(filenames) > 0) {
		/* Open the first file and start parsing it. */
		filename = filenames;
		currentfile = filename->data;
		yyin = fopen(currentfile, "r");
		yyparse();
		fclose(yyin);
	} else {
		/* Start parsing stdin. */
		currentfile = "<stdin>";
		yyin = stdin;
	}
	tail();
	return 0;
}