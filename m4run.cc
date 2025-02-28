#include <iostream>
#include <cstdlib>

// g++ -std=c++17 -Wall -o m4run m4run.cc
int main() {
  const char* m0sector    = std::getenv("m0sector");
  const char* m0name      = std::getenv("m0name");
  const char* m0output    = std::getenv("m0output");
  const char* m0input     = std::getenv("m0input");
  const char* m0tier      = std::getenv("m0tier");
  const char* m0version   = std::getenv("m0version");
  const char* m0reliance  = std::getenv("m0reliance");
  const char* m0comment   = std::getenv("m0comment");
  const char* b4Section   = std::getenv("b4Section");
  const char* c3Direction = std::getenv("c3Direction");

  std::cout << (m0sector    ? m0sector    : "") << " | "
            << (m0name      ? m0name      : "") << " | "
            << (m0output    ? m0output    : "") << " | "
            << (m0input     ? m0input     : "") << " | "
            << (m0tier      ? m0tier      : "") << " | "
            << (m0version   ? m0version   : "") << " | "
            << (m0reliance  ? m0reliance  : "") << " | "
            << (m0comment   ? m0comment   : "") << " | "
            << (b4Section   ? b4Section   : "") << " | "
            << (c3Direction ? c3Direction : "")
            << std::endl;

  return 0;
}
