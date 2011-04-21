/* Copyright (C) 2001-2010 Peter Selinger.
   This file is part of Potrace. It is free software and it is covered
   by the GNU General Public License. See the file COPYING for details. */

/* $Id: backend_pgm.h 227 2010-12-16 05:47:19Z selinger $ */

#ifndef BACKEND_PGM_H
#define BACKEND_PGM_H

#include <stdio.h>

#include "potracelib.h"
#include "main.h"

int page_pgm(FILE *fout, potrace_path_t *plist, imginfo_t *imginfo);

#endif /* BACKEND_PGM_H */
