#!/usr/bin/ruby

# Android build system is complicated and does not allow to build
# separate parts easily.
# This script tries to mimic Android build rules.

def expand(dir, files)
  files.map{|f| File.join(dir,f)}
end

# Compiles sources to *.o files.
# Returns array of output *.o filenames
def compile(sources, cflags)
  outputs = []
  for s in sources
    ext = File.extname(s)

    case ext
    when '.c'
      cc = 'cc'
      lang_flags = '-std=gnu11 $CFLAGS $CPPFLAGS'
    when '.cpp', '.cc'
      cc = 'cxx'
      lang_flags = '-std=gnu++14 $CXXFLAGS $CPPFLAGS'
    else
        raise "Unknown extension #{ext}"
    end

    output = s + '.o'
    outputs << output
    puts "build #{output}: #{cc} #{s}\n    cflags = #{lang_flags} #{cflags}"
  end

  return outputs
end

# dir - directory where ninja file is located
# lib - static library path relative to dir
def subninja(dir, lib)
  puts "subninja #{dir}build.ninja"
  return lib.each{|l| dir + l}
end

# Links object files
def link(output, objects, ldflags)
  puts "build #{output}: link #{objects.join(' ')}\n    ldflags = #{ldflags} $LDFLAGS"
end

puts "# This set of commands generated by generate_build.rb script\n\n"
puts "CC = #{ENV['CC'] || 'clang'}"
puts "CXX = #{ENV['CXX'] || 'clang++'}\n\n"
puts "CFLAGS = #{ENV['CFLAGS']}"
puts "CXXFLAGS = #{ENV['CXXFLAGS']}"
puts "LDFLAGS = #{ENV['LDFLAGS']}"
puts "PKGVER = #{ENV['PKGVER']}\n\n"


puts """
rule cc
  command = $CC $cflags -c $in -o $out

rule cxx
  command = $CXX $cflags -c $in -o $out

rule link
  command = $CXX $ldflags $LDFLAGS $in -o $out


"""

adbdfiles = %w(
  adb.cpp
  adb_io.cpp
  adb_listeners.cpp
  adb_trace.cpp
  adb_utils.cpp
  bugreport.cpp
  line_printer.cpp
  sockets.cpp
  transport.cpp
  transport_local.cpp
  transport_usb.cpp
  transport_mdns_unsupported.cpp
  fdevent.cpp
  adb_auth_host.cpp
  shell_service_protocol.cpp
)
libadbd = compile(expand('core/adb', adbdfiles), '-DADB_VERSION="\"$PKGVER\"" -DADB_HOST=1 -Icore/include -Icore/base/include -Icore/adb -Icore/libcrypto_utils/include -Iboringssl/include')

adbfiles = %w(
  console.cpp
  socket_spec.cpp
  commandline.cpp
  adb_client.cpp
  services.cpp
  file_sync_client.cpp
  sysdeps_unix.cpp
  sysdeps/errno.cpp
  client/main.cpp
  client/usb_dispatch.cpp
  client/usb_linux.cpp
  client/usb_libusb.cpp
  sysdeps/posix/network.cpp
)
libadb = compile(expand('core/adb', adbfiles), '-D_GNU_SOURCE -DADB_HOST=1 -Icore/include -Icore/base/include -Icore/adb')

basefiles = %w(
  file.cpp
  logging.cpp
  parsenetaddress.cpp
  stringprintf.cpp
  strings.cpp
  errors_unix.cpp
  test_utils.cpp
)
libbase = compile(expand('core/base', basefiles), '-DADB_HOST=1 -Icore/base/include -Icore/include')

logfiles = %w(
  log_event_write.c
  fake_log_device.c
  log_event_list.c
  logger_write.c
  config_write.c
  config_read.c
  logger_lock.c
  local_logger.c
  fake_writer.c
  logger_name.c
  stderr_write.c
  logprint.c
)
liblog = compile(expand('core/liblog', logfiles), '-DLIBLOG_LOG_TAG=1006 -D_XOPEN_SOURCE=700 -DFAKE_LOG_DEVICE=1 -Icore/log/include -Icore/include')

cutilsfiles = %w(
  load_file.c
  socket_local_client_unix.c
  socket_network_client_unix.c
  socket_local_server_unix.c
  sockets_unix.cpp
  socket_inaddr_any_server_unix.c
  sockets.cpp
  android_get_control_file.cpp
  threads.c
)
libcutils = compile(expand('core/libcutils', cutilsfiles), '-D_GNU_SOURCE -Icore/include')

diagnoseusbfiles = %w(
  diagnose_usb.cpp
)
libdiagnoseusb = compile(expand('core/adb', diagnoseusbfiles), '-Icore/include -Icore/base/include')

libcryptofiles = %w(
  android_pubkey.c
)
libcrypto = compile(expand('core/libcrypto_utils', libcryptofiles), '-Icore/libcrypto_utils/include -Iboringssl/include')

# TODO: make subninja working
#boringssl = subninja('boringssl/build/', ['crypto/libcrypto.a'])
boringssl = ['boringssl/build/crypto/libcrypto.a']

link('adb', libbase + liblog + libcutils + libadbd + libadb + libdiagnoseusb + libcrypto + boringssl, '-lpthread -lusb-1.0')


fastbootfiles = %w(
  protocol.cpp
  engine.cpp
  bootimg_utils.cpp
  fastboot.cpp
  util.cpp
  fs.cpp
  usb_linux.cpp
  socket.cpp
  tcp.cpp
  udp.cpp
)
libfastboot = compile(expand('core/fastboot', fastbootfiles), '-DFASTBOOT_VERSION="\"$PKGVER\"" -D_GNU_SOURCE -D_XOPEN_SOURCE=700 -DUSE_F2FS -Icore/base/include -Icore/include -Icore/adb -Icore/libsparse/include -Icore/mkbootimg -Iextras/ext4_utils/include -Iextras/f2fs_utils -Icore/libziparchive/include')

sparsefiles = %w(
  backed_block.c
  output_file.c
  sparse.c
  sparse_crc32.c
  sparse_err.c
  sparse_read.cpp
)
libsparse = compile(expand('core/libsparse', sparsefiles), '-Icore/libsparse/include -Icore/base/include')

f2fsfiles = %w(
  f2fs_utils.c
  f2fs_ioutils.c
  f2fs_dlutils.c
)
f2fs = compile(expand('extras/f2fs_utils', f2fsfiles), '-Iextras/f2fs_utils -If2fs-tools/include -If2fs-tools/mkfs -Icore/libsparse/include -Iselinux/libselinux/include')

zipfiles = %w(
  zip_archive.cc
)
libzip = compile(expand('core/libziparchive', zipfiles), '-Icore/base/include -Icore/include -Icore/libziparchive/include')

utilfiles = %w(
  FileMap.cpp
)
libutil = compile(expand('core/libutils', utilfiles), '-Icore/include')

ext4files = %w(
  make_ext4fs.c
  ext4fixup.c
  ext4_utils.c
  allocate.c
  contents.c
  extent.c
  indirect.c
  sha1.c
  wipe.c
  crc16.c
  ext4_sb.c
)
libext4 = compile(expand('extras/ext4_utils', ext4files), '-D_GNU_SOURCE -Icore/libsparse/include -Icore/include -Iselinux/libselinux/include -Iextras/ext4_utils/include')

selinuxfiles = %w(
  callbacks.c
  check_context.c
  freecon.c
  init.c
  label.c
  label_file.c
  label_support.c
  setrans_client.c
  regex.c
  matchpathcon.c
  selinux_config.c
  label_backends_android.c
  canonicalize_context.c
  lsetfilecon.c
  policyvers.c
  lgetfilecon.c
  load_policy.c
  seusers.c
  sha1.c
  booleans.c
  disable.c
  enabled.c
  getenforce.c
  setenforce.c
)
libselinux = compile(expand('selinux/libselinux/src', selinuxfiles), '-DAUDITD_LOG_TAG=1003 -D_GNU_SOURCE -DHOST -DUSE_PCRE2 -DNO_PERSISTENTLY_STORED_PATTERNS -DDISABLE_SETRANS -DDISABLE_BOOL -DNO_MEDIA_BACKEND -DNO_X_BACKEND -DNO_DB_BACKEND -DPCRE2_CODE_UNIT_WIDTH=8 -Iselinux/libselinux/include -Iselinux/libsepol/include')

libsepolfiles = %w(
  policydb_public.c
  genbools.c
  debug.c
  policydb.c
  conditional.c
  services.c
  ebitmap.c
  util.c
  assertion.c
  avtab.c
  hashtab.c
  sidtab.c
  context.c
  genusers.c
  context_record.c
  mls.c
  avrule_block.c
  symtab.c
  policydb_convert.c
  write.c
  constraint.c
  expand.c
  hierarchy.c
)
libsepol = compile(expand('selinux/libsepol/src', libsepolfiles), '-Iselinux/libsepol/include')

link('fastboot', libsparse + libzip + libcutils + liblog + libutil + libbase + libext4 + f2fs + libselinux + libsepol + libfastboot + libdiagnoseusb, '-lz -lpcre2-8 -lpthread -ldl')
