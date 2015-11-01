task :build do
  sh "xctool -workspace HexQL.xcodeproj/project.xcworkspace -scheme HexQL"
end

filename = "HexQL.qlgenerator-#{Time.now.to_s.split()[0]}.tar.bz2"
task :compress => :build do
  sh "tar cjvf #{filename} -C ~/Library/QuickLook HexQL.qlgenerator"
end

task :install => :build do
  sh "qlmanage -r"
end
task :default => :install
