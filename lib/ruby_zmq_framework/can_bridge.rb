require 'socket'

module RubyZmqFramework
  # Reads raw frames off a real SocketCAN interface (can0, vcan0, ...) and
  # rebroadcasts each one onto the ZeroMQ bus. Pure producer: it has no
  # interest in bus traffic, so handle_message is a no-op that only exists
  # to satisfy FrameworkModule's contract.
  #
  # Talks to the kernel directly via Ruby's built-in Socket + a couple of
  # raw ioctl/struct calls (see linux/can.h, linux/sockios.h) rather than
  # a third-party gem, since no maintained "socketcan" gem is published on
  # RubyGems.
  class CanBridge
    include FrameworkModule

    CAN_RAW       = 1
    SIOCGIFINDEX  = 0x8933
    FRAME_SIZE    = 16 # sizeof(struct can_frame): 4(id) + 1(len) + 3(pad) + 8(data)
    CAN_EFF_FLAG  = 0x80000000
    CAN_EFF_MASK  = 0x1FFFFFFF
    CAN_SFF_MASK  = 0x7FF

    def self.parse_frame(raw)
      id_raw, len = raw.unpack('L< C')
      extended = (id_raw & CAN_EFF_FLAG) != 0
      can_id = id_raw & (extended ? CAN_EFF_MASK : CAN_SFF_MASK)

      { id: can_id, extended: extended, dlc: len, data: raw[8, len].bytes }
    end

    def initialize(bus, interface:, topic: :can_frame)
      @bus = bus
      @topic = topic
      @socket = open_can_socket(interface)
      @running = true
      start_reader
    end

    def handle_message(topic, payload); end

    # Stops the whole node: heartbeat, reader thread, CAN socket. Closing
    # the socket from here is what interrupts the reader's blocking read.
    def close
      return unless @running

      @running = false
      stop_heartbeat
      @socket.close unless @socket.closed?
      @reader.join(2)
      nil
    end

    private

    def open_can_socket(interface)
      socket = Socket.new(Socket::PF_CAN, Socket::SOCK_RAW, CAN_RAW)
      socket.bind(sockaddr_can(interface_index(socket, interface)))
      socket
    end

    def interface_index(socket, interface)
      ifreq = [interface].pack('a16') + ("\0" * 24)
      socket.ioctl(SIOCGIFINDEX, ifreq)
      ifreq[16, 4].unpack1('l')
    end

    def sockaddr_can(ifindex)
      [Socket::AF_CAN, 0, ifindex].pack('S S l') + ("\0" * 8)
    end

    def start_reader
      @reader = Thread.new do
        while @running
          begin
            raw = @socket.read(FRAME_SIZE)
            broadcast(@topic, self.class.parse_frame(raw)) if raw&.bytesize == FRAME_SIZE
          rescue StandardError => e
            break unless @running # close interrupted the blocking read

            warn "[Framework Error] CanBridge read failed: #{e.message}"
            sleep 1
          end
        end
      end
    end
  end
end
