class Kedge < Formula
  desc "Deployment tool for Kubernetes artifacts"
  homepage "https://github.com/kedgeproject/kedge"
  url "https://github.com/kedgeproject/kedge/archive/v0.12.0.tar.gz"
  sha256 "3c01880ba9233fe5b0715527ba32f0c59b25b73284de8cfb49914666a158487b"
  license "Apache-2.0"

  bottle do
    sha256 cellar: :any_skip_relocation, big_sur:     "045212f9d7e995b765d681d7f6b3478fe976907cc867e663dcf6ed791e258e41"
    sha256 cellar: :any_skip_relocation, catalina:    "3edff5947ad6460ff5132a9f1722d12e9da6c3644138275b0f3423dc14efac3b"
    sha256 cellar: :any_skip_relocation, mojave:      "2302d114b01411cef00669faf00e32f1db551a9ba10402398720ca7a56cac0ec"
    sha256 cellar: :any_skip_relocation, high_sierra: "ff1bf61801e5c5e17ba83abe714c4d30914a458291cdc0fc4654ee952a919c4c"
    sha256 cellar: :any_skip_relocation, sierra:      "39f193757913fc743191091a86b5d162b4cb4af618975db1ecd649dce7a08941"
    sha256 cellar: :any_skip_relocation, el_capitan:  "1ff9804be018e8bf5bd0668ce1e1a647ab04005b4ea34fb22f49c50c215b4e13"
  end

  depends_on "go" => :build

  def install
    ENV["GOPATH"] = buildpath
    (buildpath/"src/github.com/kedgeproject").mkpath
    ln_s buildpath, buildpath/"src/github.com/kedgeproject/kedge"
    system "make", "bin"
    bin.install "kedge"
  end

  test do
    (testpath/"kedgefile.yml").write <<~EOS
      name: test
      deployments:
      - containers:
        - image: test
    EOS
    output = shell_output("#{bin}/kedge generate -f kedgefile.yml")
    assert_match "name: test", output
  end
end
