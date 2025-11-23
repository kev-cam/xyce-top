//-------------------------------------------------------------------------
//   Copyright 2002-2020 National Technology & Engineering Solutions of
//   Sandia, LLC (NTESS).  Under the terms of Contract DE-NA0003525 with
//   NTESS, the U.S. Government retains certain rights in this software.
//
//   This file is part of the Xyce(TM) Parallel Electrical Simulator.
//
//   Xyce(TM) is free software: you can redistribute it and/or modify
//   it under the terms of the GNU General Public License as published by
//   the Free Software Foundation, either version 3 of the License, or
//   (at your option) any later version.
//
//   Xyce(TM) is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.
//
//   You should have received a copy of the GNU General Public License
//   along with Xyce(TM).
//   If not, see <http://www.gnu.org/licenses/>.
//-------------------------------------------------------------------------

#include <Xyce_config.h>

#include <fstream>
#include <string>

#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
// Windows is a Special Case, and stat.h does not define this macro.
#ifndef S_ISREG
#ifdef _S_IFREG
#define S_ISREG(mode) (((mode) & _S_IFMT) == _S_IFREG)
#else
#error stat.h missing S_ISREG and _S_IFREG.  Cannot proceed
#endif
#endif
#endif

namespace Xyce{
namespace Util {

//-----------------------------------------------------------------------------
// Function      : checkIfValidURI
// Purpose       : Verify that a user-specified URI is valid.
// Special Notes : This may only do a syntax check.
// Creator       : Kevin Cameron
// Creation Date : 04/22/2020
//-----------------------------------------------------------------------------

bool checkIfValidURI(std::string netlist_urispec)
{
  bool isValidURI = false;

  if (0 == netlist_urispec.find("code:")) {
      // Shared library, and entry-point
    isValidURI = true;
  }

  return isValidURI;
}

} // namespace Util
} // namespace Xyce
