m4_pattern_allow([^AU_])

# AU_CHECK_LIB_SONAME(VARIABLE, LIBRARY, FUNCTION,
#                     [ACTION-IF-FOUND], [ACTION-IF-FOUND-BUT-NO-SONAME],
#                     [ACTION-IF-NOT-FOUND],
#                     [OTHER-LIBRARIES])
#------------------------------------------------------------------------
# This is similar to AC_CHECK_LIB, but also sets LIB${VARIABLE}_SONAME
# If SONAME is not found and ACTION-IF-FOUND-BUT-NO-SONAME is called,
# it still does things which does AC_CHECK_LIB for ACTION-IF-FOUND.
AC_DEFUN([AU_CHECK_LIB_SONAME], [
  AC_REQUIRE([LT_INIT])
  AS_VAR_PUSHDEF([ac_Lib_SONAME], [au_cv_lib_soname_$1])
  AC_ARG_VAR([$1][_SONAME], [SONAME of lib$2, overriding objdump check])
  AC_CHECK_LIB($2,$3,[
    AC_PATH_PROG([PATH_OBJDUMP], [objdump])
    AC_CACHE_CHECK([for SONAME of lib$2], [ac_Lib_SONAME],[
      AS_IF([test x"$[$1][_SONAME]" = x""], [
        AS_IF([test x"$PATH_OBJDUMP" != x""], [
          AS_VAR_SET([ac_Lib_SONAME], ["unknown"])
          AU_CHECK_LIB_SONAME_LIBS="$LIBS"
          LIBS="$LIBS $7 -l$2"
          shrext_regexp=`echo "$shrext_cmds" | sed 's/\./\\\\./'`
          AC_LINK_IFELSE([AC_LANG_PROGRAM([[
void libusb_close(void *);
]], [[
libusb_close((void*)0);
]])],
              [AS_VAR_SET([ac_Lib_SONAME], [`objdump -p conftest$ac_exeext | sed -n 's/@<:@ \t@:>@\+NEEDED@<:@ \t@:>@\+\('lib[$2]$shrext_regexp'.*\)$/\1/p'`])])
          LIBS="$AU_CHECK_LIB_SONAME_LIBS"
          AS_IF([test x"$ac_Lib_SONAME" = x ],
            [AS_VAR_SET([ac_Lib_SONAME], [unknown])])
          AS_IF([test x"$ac_Lib_SONAME" != x"unknown" ], [
            AS_VAR_SET([$1][_SONAME], ["$ac_Lib_SONAME"])
            $4])], [
          AS_VAR_SET([ac_Lib_SONAME], [unknown])
          $5])], [
        AS_VAR_SET([ac_Lib_SONAME], ["$[$1][_SONAME]"])
        $4])])],
    [$6], [$7])
  AS_VAR_POPDEF([ac_Lib_SONAME])
])
