import asyncio
import unittest
import zlib

from pulsebridge_sim import firmware as fw
from pulsebridge_sim import protocol as p
from pulsebridge_sim.device import Device, DeviceConfig

IMAGE = fw.build_image("1.1.0", size=4096)
BEGIN = fw.FwBegin(len(IMAGE), zlib.crc32(IMAGE), "1.1.0")


class BootloaderTest(unittest.TestCase):
    def test_installs_a_verified_image(self):
        boot = fw.Bootloader("1.0.0")
        self.assertEqual(boot.begin(BEGIN).state, fw.FwState.RECEIVING)
        for offset in range(0, len(IMAGE), 512):
            status = boot.chunk(fw.FwChunk(offset, IMAGE[offset:offset + 512]))
        self.assertEqual(status.received, len(IMAGE))
        self.assertEqual(boot.commit().state, fw.FwState.INSTALLED)
        self.assertEqual(boot.running, "1.1.0")

    def test_resumes_the_same_image_where_it_stopped(self):
        boot = fw.Bootloader("1.0.0")
        boot.begin(BEGIN)
        boot.chunk(fw.FwChunk(0, IMAGE[:500]))
        boot.chunk(fw.FwChunk(500, IMAGE[500:1000]))
        self.assertEqual(boot.begin(BEGIN).received, 1000, "same image: keep the bytes")
        other = fw.FwBegin(len(IMAGE), BEGIN.crc32 ^ 1, "1.1.0")
        self.assertEqual(boot.begin(other).received, 0, "different image: start over")

    def test_repeated_and_early_chunks_change_nothing(self):
        boot = fw.Bootloader("1.0.0")
        boot.begin(BEGIN)
        boot.chunk(fw.FwChunk(0, IMAGE[:100]))
        self.assertEqual(boot.chunk(fw.FwChunk(0, IMAGE[:100])).received, 100)
        self.assertEqual(boot.chunk(fw.FwChunk(500, IMAGE[500:600])).received, 100)

    def test_a_corrupted_image_is_rejected_and_the_old_version_kept(self):
        boot = fw.Bootloader("1.0.0", corrupt_flash=True)
        boot.begin(BEGIN)
        boot.chunk(fw.FwChunk(0, IMAGE[:512]))
        for offset in range(512, len(IMAGE), 512):
            boot.chunk(fw.FwChunk(offset, IMAGE[offset:offset + 512]))
        status = boot.commit()
        self.assertEqual(status.state, fw.FwState.REJECTED)
        self.assertIn("checksum", status.detail)
        self.assertEqual(boot.running, "1.0.0")

    def test_an_image_for_another_version_is_rejected(self):
        boot = fw.Bootloader("1.0.0")
        wrong = fw.FwBegin(len(IMAGE), zlib.crc32(IMAGE), "2.0.0")
        boot.begin(wrong)
        for offset in range(0, len(IMAGE), 512):
            boot.chunk(fw.FwChunk(offset, IMAGE[offset:offset + 512]))
        self.assertEqual(boot.commit().state, fw.FwState.REJECTED)
        self.assertEqual(boot.running, "1.0.0")

    def test_oversized_chunks_are_refused(self):
        boot = fw.Bootloader("1.0.0")
        boot.begin(BEGIN)
        self.assertEqual(boot.chunk(fw.FwChunk(0, IMAGE[:fw.MAX_CHUNK + 1])).state, fw.FwState.REJECTED)

    def test_commit_before_the_end_does_not_install(self):
        boot = fw.Bootloader("1.0.0")
        boot.begin(BEGIN)
        boot.chunk(fw.FwChunk(0, IMAGE[:100]))
        self.assertEqual(boot.commit().state, fw.FwState.RECEIVING)
        self.assertEqual(boot.running, "1.0.0")


class FirmwareOverTheLinkTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.device = Device(DeviceConfig(speed=20, seed=1, boot_seconds=0.1))
        self.server = await self.device.serve("127.0.0.1", 0)
        self.port = self.server.sockets[0].getsockname()[1]

    async def asyncTearDown(self):
        self.server.close()
        await self.server.wait_closed()

    async def connect(self):
        reader, writer = await asyncio.open_connection("127.0.0.1", self.port)
        return reader, writer, p.FrameDecoder()

    async def command(self, conn, msg_type, payload=b""):
        reader, writer, decoder = conn
        writer.write(p.encode(p.Frame(msg_type, 1, payload)))
        await writer.drain()
        while True:
            data = await asyncio.wait_for(reader.read(4096), 2)
            if not data:
                raise ConnectionError("closed")
            for frame in decoder.feed(data):
                if frame.type == p.MessageType.FW_STATUS:
                    return fw.FwStatus.unpack(frame.payload)

    async def test_update_then_restart_with_the_new_version(self):
        conn = await self.connect()
        self.assertEqual((await self.command(conn, p.MessageType.FW_BEGIN, BEGIN.pack())).received, 0)
        for offset in range(0, len(IMAGE), 512):
            await self.command(conn, p.MessageType.FW_CHUNK, fw.FwChunk(offset, IMAGE[offset:offset + 512]).pack())
        status = await self.command(conn, p.MessageType.FW_COMMIT)
        self.assertEqual(status.state, fw.FwState.INSTALLED)

        # The device closes the link to restart, then greets with the new version.
        self.assertEqual(await asyncio.wait_for(conn[0].read(), 2), b"")
        conn[1].close()
        await asyncio.sleep(0.2)
        reader, writer, decoder = await self.connect()
        data = await asyncio.wait_for(reader.read(4096), 2)
        hello = next(f for f in decoder.feed(data) if f.type == p.MessageType.HELLO)
        self.assertEqual(p.Hello.unpack(hello.payload).firmware, "1.1.0")
        writer.close()

    async def test_refuses_to_update_while_streaming(self):
        conn = await self.connect()
        conn[1].write(p.encode(p.Frame(p.MessageType.START_STREAM, 1)))
        status = await self.command(conn, p.MessageType.FW_BEGIN, BEGIN.pack())
        self.assertEqual(status.state, fw.FwState.REJECTED)
        conn[1].close()


if __name__ == "__main__":
    unittest.main()
