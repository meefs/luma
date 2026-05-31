import { TraceBuffer, TraceBufferReader } from "frida-itrace";

const readers = new Map<string, TraceBufferReader>();

rpc.exports = {
    openBuffer(sessionId: string, location: string) {
        const buffer = TraceBuffer.open(location);
        readers.set(sessionId, new TraceBufferReader(buffer));
    },

    drain(sessionId: string): ArrayBuffer | null {
        const reader = readers.get(sessionId);
        if (reader === undefined) {
            return null;
        }
        const chunk = reader.read();
        return chunk.byteLength > 0 ? chunk : null;
    },

    getLost(sessionId: string): number {
        return readers.get(sessionId)?.lost ?? 0;
    },

    close(sessionId: string): ArrayBuffer | null {
        const reader = readers.get(sessionId);
        if (reader === undefined) {
            return null;
        }
        const chunk = reader.read();
        readers.delete(sessionId);
        return chunk.byteLength > 0 ? chunk : null;
    },
};
