{ stdenv, fetchgit, wrapGAppsHook, libhandy, python3Packages, libadwaita, gtk3
, glib, meson, pkgconfig, cmake, gobject-introspection, ninja, lib }:

stdenv.mkDerivation rec {
  pname = "hydrapaper";
  version = "2.0.3";

  name = "${pname}-${version}";

  src = fetchgit {
    url = "https://gitlab.gnome.org/GabMus/HydraPaper.git";
    rev = "3b6ae84666c361aa4abae0125ee30a83d691f615";
    sha256 = "sha256-lWa4MTFF8xV3PkGWt2V031ofXu9gkS9EU/oi/a1U7dk=";
  };

  buildInputs = [ libadwaita gtk3 libhandy ];

  propagatedBuildInputs = with python3Packages; [
    pillow
    gobject-introspection
    pygobject3
  ];

  nativeBuildInputs = [ wrapGAppsHook meson ninja pkgconfig cmake glib.dev ];

  meta = with lib; {
    homepage = "https://hydrapaper.gabmus.org/";
    description =
      "IRC chat client designed to integrate with the GNOME desktop";
    maintainers = teams.gnome.members;
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
