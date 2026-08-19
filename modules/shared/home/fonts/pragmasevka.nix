# Pragmasevka: a PragmataPro-styled Iosevka build, pre-patched with Nerd Font
# glyphs. Unlike Iosevka/ZedMono (whose geometric + symbol glyphs render at
# ~128% of the cell and overflow into the next column in non-clipping
# terminals like Ghostty), Pragmasevka retunes those glyphs to PragmataPro's
# in-cell widths while keeping full Nerd Font PUA coverage. Not in nixpkgs;
# the release zip is freely redistributable so we package it from upstream.
{ stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation {
  pname = "pragmasevka-nf";
  version = "1.7.0";
  src = fetchzip {
    url = "https://github.com/shytikov/pragmasevka/releases/download/v1.7.0/Pragmasevka_NF.zip";
    hash = "sha256-QI4CHyZa3WxxGwhAZl+8d1uqcmM2tFgVwvfzGf32pcc=";
    stripRoot = false;
  };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 *.ttf -t $out/share/fonts/truetype/Pragmasevka
    runHook postInstall
  '';
  meta = {
    description = "Pragmasevka Nerd Font (PragmataPro-like Iosevka build, Nerd-Font-patched)";
    homepage = "https://github.com/shytikov/pragmasevka";
  };
}
