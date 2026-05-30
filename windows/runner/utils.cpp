#include "utils.h"

#include <flutter_windows.h>

#include <shellapi.h>
#include <string>
#include <vector>

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t **argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return {};
  }

  std::vector<std::string> arguments;
  for (int i = 0; i < argc; i++) {
    arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);
  return arguments;
}
