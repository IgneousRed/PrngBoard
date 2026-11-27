# Published native dependency releases absent from the locked catalog.
# Hashes cover the fetched source, recursively unpacked for GitHub sources and
# flat release archives for Git/Perl. Keep the common lock and recipe features.
{
  zstd = {
    version = "1.6.0";
    tag = "v1.6.0";
    hash = "sha256-bzIcrgp7uYeJ+LEv6Nb9Nd41jGfJvUvDZ0nxQBu5Tvo=";
  };
  git = {
    version = "2.56.1";
    url = "https://www.kernel.org/pub/software/scm/git/git-2.56.1.tar.xz";
    hash = "sha256-8LC/iSZLm9LhxkA2PnUpZDmJ2nYoFgBHPFB0XNNKYH8=";
  };
  perl = {
    version = "5.44.0";
    url = "https://www.cpan.org/src/5.0/perl-5.44.0.tar.gz";
    hash = "sha256-O4VQZrkkkctA6Gr/scpX0aOIqkPlG5HHgGoywvZflsM=";
  };
  sigtool = {
    version = "0.2.3";
    tag = "v0.2.3";
    hash = "sha256-bybUgdGArOPkhjIby58TGtwv1kOGgWi9MEL+Bb7SV8A=";
  };
  sqlite = {
    version = "3.54.1";
    url = "https://sqlite.org/2026/sqlite-src-3540100.zip";
    hash = "sha256-OH5/bK1Hl7F4SMB9RT3GYGkXuzVqbP5aOrr9OMJAxxs=";
  };
  sqlite_doc = {
    version = "3.54.1";
    url = "https://sqlite.org/2026/sqlite-doc-3540100.zip";
    hash = "sha256-6fY0rCikx7SPXDieSwjAOWVOwUh1EgkrMwzPz9wIFuA=";
  };
  expat = {
    version = "2.11.0";
    url = "https://github.com/libexpat/libexpat/releases/download/R_2_11_0/expat-2.11.0.tar.xz";
    hash = "sha256-YedhS2AiAcKKGJ2v7nj1vOruGSu95GqTB1L/Cc9VQvo=";
  };
  zlib = {
    version = "1.4";
    url = "https://github.com/madler/zlib/releases/download/v1.4/zlib-1.4.tar.gz";
    hash = "sha256-At0Vl4NnenScBK290CtVuKK8x+BU9Rt2tUkZmpFq1YQ=";
  };
  libffiReal = {
    version = "3.8.2";
    url = "https://github.com/libffi/libffi/releases/download/v3.8.2/libffi-3.8.2.tar.gz";
    hash = "sha256-ppn9orCQxLRst5z2DE2s/OSA6wV0LA3mas868XSkf5I=";
  };
  simdjson = {
    version = "5.3.0";
    hash = "sha256-H3VdveURQt6s/zIT2MWmxqUSdPKjNv90O/aXrcztDkA=";
    owner = "simdjson";
    repo = "simdjson";
    tag = "v5.3.0";
  };
  simdutf = {
    version = "9.5.0";
    hash = "sha256-cukWp4Q3+P5LsYmmrcqrKc+E7Bf7HUr2LM9Xanf+73E=";
    owner = "simdutf";
    repo = "simdutf";
    tag = "v9.5.0";
  };
  llhttp = {
    version = "9.4.4";
    hash = "sha256-ZJVC37wbsZ7DbqtiaQqe1EVYTsR7tNxXUQT5L8rbACo=";
    owner = "nodejs";
    repo = "llhttp";
    tag = "release/v9.4.4";
  };
  ada = {
    version = "4.1.1";
    hash = "sha256-Rwn8bKG6PEVUMCj0Oz6/BGFRH25IoyGf1iMWvGXm4r4=";
    owner = "ada-url";
    repo = "ada";
    tag = "v4.1.1";
  };
  nbytes = {
    version = "0.1.5";
    hash = "sha256-D0RLpE/UWhqFVy7dR5UOy5O5K6kP5Al0P7NaoP5aIOM=";
    owner = "nodejs";
    repo = "nbytes";
    tag = "v0.1.5";
  };
  nghttp2 = {
    version = "1.71.0";
    hash = "sha256-IlVe1/HKgLfNdmWe0tuqBBJC0dv7LBX4jv5Nk66VNTc=";
    url = "https://github.com/nghttp2/nghttp2/releases/download/v1.71.0/nghttp2-1.71.0.tar.bz2";
  };
  nghttp3 = {
    version = "1.19.0";
    hash = "sha256-4RVyQwioub5Ooe7kmoZH9vJicbZh+r9Y2BQ78UII4LI=";
    url = "https://github.com/ngtcp2/nghttp3/releases/download/v1.19.0/nghttp3-1.19.0.tar.bz2";
  };
  ngtcp2 = {
    version = "1.26.0";
    hash = "sha256-991AnizQ8a9Lx5C+Xjf2BsDoa19pkp0S4hUiCuFPINk=";
    url = "https://github.com/ngtcp2/ngtcp2/releases/download/v1.26.0/ngtcp2-1.26.0.tar.bz2";
  };
  gtest = {
    version = "1.18.0";
    hash = "sha256-rXsn2L0xeWvfxTjMAoWEu0UFZ7xOSfYmhbKgRF5J9co=";
    owner = "google";
    repo = "googletest";
    tag = "v1.18.0";
  };
  hdrhistogram_c = {
    version = "0.12.1";
    hash = "sha256-g21W1XHP/GxTI5Ifsj49SjLQdaXh0SFKzQiAnMZmv10=";
    owner = "HdrHistogram";
    repo = "HdrHistogram_c";
    tag = "0.12.1";
  };
  readline = {
    version = "8.3p6";
    patches = [
      { url = "https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-004"; hash = "sha256-HxicRWaqNZUJZGR7nsO+GoIeQrhgSBKcY+t/nU0vWnQ="; }
      { url = "https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-005"; hash = "sha256-VIGtvhYcn2upcsdNueGMeqNR098wNcxKZzoaoGJH0cY="; }
      { url = "https://ftp.gnu.org/gnu/readline/readline-8.3-patches/readline83-006"; hash = "sha256-Tr0mGmCCh3luFxrw6pr1oeMSLkZnKszaJIS2aYxHwaQ="; }
    ];
  };
  libunistring = {
    version = "1.5";
    url = "https://ftp.gnu.org/gnu/libunistring/libunistring-1.5.tar.xz";
    hash = "sha256-/okAeopBSuR5C4FrhoWeh306sTXbPDfwZUH/foWsNEs=";
  };
  libiconvReal = {
    version = "1.19.1";
    url = "https://ftp.gnu.org/gnu/libiconv/libiconv-1.19.1.tar.gz";
    hash = "sha256-mgaESEbWZNcSIWFwDBCmRIDXx7zq0wkZJaeFs4yR7as=";
  };
  publicsuffix-list = {
    version = "0-unstable-2026-11-26";
    rev = "59540d8dd711a8e49b69eaf52c3e1b9f39b1035b";
    hash = "sha256-xnQGqpKB9NRPIJv0u9VipWivw0uch+8Hlb/GVlmv33U=";
  };
  glfw = {
    version = "3.5.1";
    hash = "sha256-Vwi7MbzrQmcsENez987/Ju7H0pz0tSV6YC0DqwGeQ+w=";
    owner = "glfw";
    repo = "glfw";
    tag = "3.5.1";
  };
  krb5 = {
    version = "1.22.3";
    hash = "sha256-/pCvhEGtn6mwZLjlMHfO+3gqlvimgnawMdxUrxeJ/ws=";
    url = "https://kerberos.org/dist/krb5/1.22/krb5-1.22.3.tar.gz";
  };
  cmake = {
    version = "4.5.1";
    url = "https://github.com/Kitware/CMake/releases/download/v4.5.1/cmake-4.5.1.tar.gz";
    hash = "sha256-p5vzPL4FaG/fecK7vP5ejmKtFtPVQPpzfL7f7tQftp4=";
  };
  libarchive = {
    version = "3.8.11";
    owner = "libarchive";
    repo = "libarchive";
    tag = "v3.8.11";
    hash = "sha256-jkcTcc5w2mENlQIjgpcM1fJ7r9yGEJY7X6129nVuypQ=";
  };
  gbenchmark = {
    version = "1.10.0";
    owner = "google";
    repo = "benchmark";
    tag = "v1.10.0";
    hash = "sha256-yJzrkJxJUtCXmBJK474mu4MHJTT6ZnNnBRNwuCkRHEo=";
  };
  rustLLVM = {
    version = "23.1.6";
    hash = "sha256-zhZdCo2xbt9G9wKTsLsjDZcdA+zn+fi9ygd0hkNe3Rc=";
  };
  libplist = {
    version = "2.8.1";
    owner = "libimobiledevice";
    repo = "libplist";
    tag = "2.8.1";
    hash = "sha256-ZKFN8FVUNj3SiYY3lpFMYYBJ2Ji6hCxye69ROJO/pK0=";
  };
  libedit = {
    version = "20260512-3.1";
    url = "https://thrysoee.dk/editline/libedit-20260512-3.1.tar.gz";
    hash = "sha256-Qy1efqiwEW3Tny7Ke8EdDu13+qa3fqUmrOiZB8I+pKA=";
  };
  tcl = {
    version = "8.6.18";
    url = "https://downloads.sourceforge.net/tcl/tcl8.6.18-src.tar.gz";
    hash = "sha256-FPmvMrF2f/cYR3qPl0rQPDQ0EJfmtD9M5UZE7pdOJo4=";
  };
  gtk-doc = {
    version = "1.37.0";
    url = "https://download.gnome.org/sources/gtk-doc/1.37/gtk-doc-1.37.0.tar.xz";
    hash = "sha256-L6z7Uw3c0gwD7UdY75NOgyYmw5Piys0j/BJJt+0OQkY=";
  };
}
