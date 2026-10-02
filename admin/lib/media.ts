// Browser-only helpers: read video/image size and make a JPEG thumbnail.

export const MAX_UPLOAD_BYTES = 50 * 1024 * 1024; // Supabase free plan limit
const THUMB_WIDTH = 480;

export type MediaInfo = {
  kind: "video" | "image";
  width: number;
  height: number;
  durationS: number | null;
  thumbnail: Blob;
};

function canvasToJpeg(source: CanvasImageSource, width: number, height: number): Promise<Blob> {
  const scale = Math.min(1, THUMB_WIDTH / width);
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(width * scale);
  canvas.height = Math.round(height * scale);
  canvas.getContext("2d")!.drawImage(source, 0, 0, canvas.width, canvas.height);
  return new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("thumbnail failed"))), "image/jpeg", 0.8),
  );
}

function readImage(file: File): Promise<MediaInfo> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = async () => {
      try {
        const thumbnail = await canvasToJpeg(img, img.naturalWidth, img.naturalHeight);
        resolve({ kind: "image", width: img.naturalWidth, height: img.naturalHeight, durationS: null, thumbnail });
      } catch (e) {
        reject(e);
      } finally {
        URL.revokeObjectURL(url);
      }
    };
    img.onerror = () => reject(new Error(`Can't read image ${file.name}`));
    img.src = url;
  });
}

function readVideo(file: File): Promise<MediaInfo> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement("video");
    video.preload = "auto";
    video.muted = true;
    video.playsInline = true;
    video.onloadedmetadata = () => {
      // Grab a frame a little way in (avoids black first frames).
      video.currentTime = Math.min(1, (video.duration || 0) / 3);
    };
    video.onseeked = async () => {
      try {
        const thumbnail = await canvasToJpeg(video, video.videoWidth, video.videoHeight);
        resolve({
          kind: "video",
          width: video.videoWidth,
          height: video.videoHeight,
          durationS: Number.isFinite(video.duration) ? Math.round(video.duration) : null,
          thumbnail,
        });
      } catch (e) {
        reject(e);
      } finally {
        URL.revokeObjectURL(url);
      }
    };
    video.onerror = () => reject(new Error(`Can't read video ${file.name} (use MP4/H.264)`));
    video.src = url;
  });
}

export function readMedia(file: File): Promise<MediaInfo> {
  if (file.type.startsWith("video/")) return readVideo(file);
  if (file.type.startsWith("image/")) return readImage(file);
  return Promise.reject(new Error(`${file.name} is not a video or image`));
}

export function extension(file: File) {
  const fromName = file.name.includes(".") ? file.name.split(".").pop()!.toLowerCase() : "";
  return fromName || file.type.split("/")[1] || "bin";
}

export function formatBytes(bytes: number) {
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}
