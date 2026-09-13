/** Decode an app-owned audio file to 16 kHz mono signed little-endian PCM in a new cache file. */
export const decodeToPcm: (source: string, destination: string, jobId: string) => Promise<number>;
export const cancelDecode: (jobId: string) => void;
