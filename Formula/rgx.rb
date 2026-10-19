class Rgx < Formula
  desc "Native RafayGen coding agent for your terminal"
  homepage "https://github.com/rafay0342/homebrew-tap"
  version "5.1.2"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-macos-arm64.tar.gz"
      sha256 "995d31107273617996539bc14e8dc68aa4dcee220aea68960b559184154d4fde"
    end
    on_intel do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-macos-x64.tar.gz"
      sha256 "ed2e7be4877eb84838c81a9767bc5fe680c8e1cc69ccff0fcb76192fea0afb17"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-linux-arm64-musl.tar.gz"
      sha256 "12571ac1bbd53664a4429ad6b78633824a6b159b0bbc593cfefe02b6054857cb"
    end
    on_intel do
      url "https://github.com/rafay0342/homebrew-tap/releases/download/v5.1.2/rgx-5.1.2-linux-x64-musl.tar.gz"
      sha256 "636d941ddd761feacf58089d9b7b2488bcc0becc1054b237a20d2b5ebd418871"
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
