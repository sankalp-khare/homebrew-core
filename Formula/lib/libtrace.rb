class Libtrace < Formula
  desc "Library for trace processing supporting multiple inputs"
  homepage "https://github.com/LibtraceTeam/libtrace"
  url "https://github.com/LibtraceTeam/libtrace/archive/refs/tags/4.0.24-1.tar.gz"
  version "4.0.24"
  sha256 "862aa272021e3883af6616e39882f29afa0ec33203e4b4e2abf08094b6cb0ae3"
  license all_of: ["GPL-2.0-or-later", "LGPL-3.0-or-later"]

  livecheck do
    url :stable
    regex(/^v?(\d+(?:[.-]\d+)+)$/i)
    strategy :git do |tags, regex|
      tags.map { |tag| tag[regex, 1]&.gsub(/-1$/, "") }.compact
    end
  end

  bottle do
    sha256 cellar: :any,                 arm64_sonoma:   "a7894a52accc6f049aab873a43026357744753dbe018be78e2d7eee265eb32ca"
    sha256 cellar: :any,                 arm64_ventura:  "ddd7d612ac62a4725e405a17d7d554bc176bffbc6e5d548ed19e51642cc52987"
    sha256 cellar: :any,                 arm64_monterey: "d0847de41f4ace8fe1ba6ab96dad6f3be6eaa09db10d51a3e46271273ee381a3"
    sha256 cellar: :any,                 sonoma:         "5d7c31a2c8676e65bbc9dd470e296bef5174e79c288625ad0b383aeea83842ee"
    sha256 cellar: :any,                 ventura:        "498b355a65704ff475773bf7aa6517784ce2a4b2b6e1a1ba6447ca47cb2b0441"
    sha256 cellar: :any,                 monterey:       "fba7945bbf904bd35c2e055399b58c1df52aa262a8226541936c18870c83795e"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "9e83968c31a6951a48cfc4af39a578a8573f6ee6b3ac933b58535d54cad9eb64"
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "openssl@3"
  depends_on "wandio"

  uses_from_macos "bison" => :build
  uses_from_macos "flex" => :build
  uses_from_macos "libpcap"

  resource "homebrew-8021x.pcap" do
    url "https://github.com/LibtraceTeam/libtrace/raw/9e82eabc39bc491c74cc4215d7eda5f07b85a8f5/test/traces/8021x.pcap"
    sha256 "aa036e997d7bec2fa3d387e3ad669eba461036b9a89b79dcf63017a2c4dac725"
  end

  def install
    system "./bootstrap.sh"
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <libtrace.h>
      #include <inttypes.h>
      #include <stdio.h>
      #include <getopt.h>
      #include <stdlib.h>
      #include <string.h>

      double lastts = 0.0;
      uint64_t v4_packets=0;
      uint64_t v6_packets=0;
      uint64_t udp_packets=0;
      uint64_t tcp_packets=0;
      uint64_t icmp_packets=0;
      uint64_t ok_packets=0;

      static void per_packet(libtrace_packet_t *packet)
      {
        /* Packet data */
        uint32_t remaining;
        /* L3 data */
        void *l3;
        uint16_t ethertype;
        /* Transport data */
        void *transport;
        uint8_t proto;
        /* Payload data */
        void *payload;

        if (lastts < 1)
          lastts = trace_get_seconds(packet);

        if (lastts+1.0 < trace_get_seconds(packet)) {
          ++lastts;
          printf("%.03f,",lastts);
          printf("%"PRIu64",%"PRIu64",",v4_packets,v6_packets);
          printf("%"PRIu64",%"PRIu64",%"PRIu64,icmp_packets,tcp_packets,udp_packets);
          printf("\\n");
          v4_packets=v6_packets=0;
          icmp_packets=tcp_packets=udp_packets=0;
        }

        l3 = trace_get_layer3(packet,&ethertype,&remaining);

        if (!l3)
          /* Probable ARP or something */
          return;

        /* Get the UDP/TCP/ICMP header from the IPv4_packets/IPv6_packets packet */
        switch (ethertype) {
          case 0x0800:
            transport = trace_get_payload_from_ip(
                (libtrace_ip_t*)l3,
                &proto,
                &remaining);
            if (!transport)
              return;
            ++v4_packets;
            break;
          case 0x86DD:
            transport = trace_get_payload_from_ip6(
                (libtrace_ip6_t*)l3,
                &proto,
                &remaining);
            if (!transport)
              return;
            ++v6_packets;
            break;
          default:
            return;
        }

        /* Parse the udp_packets/tcp_packets/icmp_packets payload */
        switch(proto) {
          case 1:
            ++icmp_packets;
            return;
          case 6:
            payload = trace_get_payload_from_tcp(
                (libtrace_tcp_t*)transport,
                &remaining);
            if (!payload)
              return;

            ++tcp_packets;
            break;
          case 17:

            payload = trace_get_payload_from_udp(
                (libtrace_udp_t*)transport,
                &remaining);
            if (!payload)
              return;
            ++udp_packets;
            break;
          default:
            return;
        }
        ++ok_packets;
      }

      static void usage(char *argv0)
      {
        fprintf(stderr,"usage: %s [ --filter | -f bpfexp ]  [ --snaplen | -s snap ]\\n\\t\\t[ --promisc | -p flag] [ --help | -h ] [ --libtrace-help | -H ] libtraceuri...\\n",argv0);
      }

      int main(int argc, char *argv[])
      {
        libtrace_t *trace;
        libtrace_packet_t *packet;
        libtrace_filter_t *filter=NULL;
        int snaplen=-1;
        int promisc=-1;

        while(1) {
          int option_index;
          struct option long_options[] = {
            { "filter",   1, 0, 'f' },
            { "snaplen",    1, 0, 's' },
            { "promisc",    1, 0, 'p' },
            { "help",   0, 0, 'h' },
            { "libtrace-help",  0, 0, 'H' },
            { NULL,     0, 0, 0 }
          };

          int c= getopt_long(argc, argv, "f:s:p:hH",
              long_options, &option_index);

          if (c==-1)
            break;

          switch (c) {
            case 'f':
              filter=trace_create_filter(optarg);
              break;
            case 's':
              snaplen=atoi(optarg);
              break;
            case 'p':
              promisc=atoi(optarg);
              break;
            case 'H':
              trace_help();
              return 1;
            default:
              fprintf(stderr,"Unknown option: %c\\n",c);
              /* FALL THRU */
            case 'h':
              usage(argv[0]);
              return 1;
          }
        }

        if (optind>=argc) {
          fprintf(stderr,"Missing input uri\\n");
          usage(argv[0]);
          return 1;
        }

        while (optind<argc) {
          trace = trace_create(argv[optind]);
          ++optind;

          if (trace_is_err(trace)) {
            trace_perror(trace,"Opening trace file");
            return 1;
          }

          if (snaplen>0)
            if (trace_config(trace,TRACE_OPTION_SNAPLEN,&snaplen)) {
              trace_perror(trace,"ignoring: ");
            }
          if (filter)
            if (trace_config(trace,TRACE_OPTION_FILTER,filter)) {
              trace_perror(trace,"ignoring: ");
            }
          if (promisc!=-1) {
            if (trace_config(trace,TRACE_OPTION_PROMISC,&promisc)) {
              trace_perror(trace,"ignoring: ");
            }
          }

          if (trace_start(trace)) {
            trace_perror(trace,"Starting trace");
            trace_destroy(trace);
            return 1;
          }

          packet = trace_create_packet();

          while (trace_read_packet(trace,packet)>0) {
            per_packet(packet);
          }

          trace_destroy_packet(packet);

          if (trace_is_err(trace)) {
            trace_perror(trace,"Reading packets");
          }

          trace_destroy(trace);
        }
              if (filter) {
                      trace_destroy_filter(filter);
              }
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-ltrace", "-o", "test"
    resource("homebrew-8021x.pcap").stage testpath
    system "./test", testpath/"8021x.pcap"
  end
end
