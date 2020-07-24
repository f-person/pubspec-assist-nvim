autocmd BufEnter pubspec.yaml command! -buffer -nargs=* PubspecAssistAddDependency lua require("pubspec-assist-nvim").pubspec_add_dependency(<q-args>)
autocmd BufEnter pubspec.yaml command! -buffer -nargs=* PubspecAssistAddDevDependency lua require("pubspec-assist-nvim").pubspec_add_dev_dependency(<q-args>)
