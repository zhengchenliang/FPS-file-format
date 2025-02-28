#include <stdio.h>
#include <stdlib.h>

// gcc -std=c99 -Wall -o m3run m3run.c
int main(void) {
  const char* m0sector    = getenv("m0sector");
  const char* m0name      = getenv("m0name");
  const char* m0output    = getenv("m0output");
  const char* m0input     = getenv("m0input");
  const char* m0tier      = getenv("m0tier");
  const char* m0version   = getenv("m0version");
  const char* m0reliance  = getenv("m0reliance");
  const char* m0comment   = getenv("m0comment");
  const char* b4Section   = getenv("b4Section");
  const char* c3Direction = getenv("c3Direction");

  printf("%s | %s | %s | %s | %s | %s | %s | %s | %s | %s\n",
         m0sector    ? m0sector    : "",
         m0name      ? m0name      : "",
         m0output    ? m0output    : "",
         m0input     ? m0input     : "",
         m0tier      ? m0tier      : "",
         m0version   ? m0version   : "",
         m0reliance  ? m0reliance  : "",
         m0comment   ? m0comment   : "",
         b4Section   ? b4Section   : "",
         c3Direction ? c3Direction : "");

  return 0;
}
