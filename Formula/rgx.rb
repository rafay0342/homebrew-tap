class Rgx < Formula
  desc "Native RafayGen coding agent for your terminal"
  homepage "https://github.com/rafay0342/homebrew-tap"
  version "5.1.2"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-macos-arm64.tar.gz"
      sha256 "eb224e123aabb729f4e877185c40a20ebb801982e31799c2e0a6538f8816af51"
    end
    on_intel do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-macos-x64.tar.gz"
      sha256 "3a1d945e8297d1fa6bc502ade951212b7a6528540024ee947a7ee7e69d045aef"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-linux-arm64-musl.tar.gz"
      sha256 "afca3255d2b6c3147f8fb2032be3a6417b54db8718def1f44d42755159604b14"
    end
    on_intel do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-linux-x64-musl.tar.gz"
      sha256 "d007c2ee054a282b221505aa90538a8fe1d82123071ddca4ec90d890561ee28c"
    end
  end

  def install
    bin.install Dir["rgx-*"][0] => "rgx"
  end

  test do
    assert_equal "rgx #{version}\n", shell_output("#{bin}/rgx --version")
    assert_match "router", shell_output("#{bin}/rgx --help")
  end
end
