import { spawn } from "node:child_process";

const child = spawn(
  "powershell.exe",
  [
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    "Start-Process 'https://studio.tripo3d.ai/'",
  ],
  { detached: true, stdio: "ignore" },
);

child.unref();
console.log("Tripo Studio solicitado no seu navegador padrão.");
