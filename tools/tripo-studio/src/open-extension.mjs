import { spawn } from "node:child_process";

const child = spawn(
  "powershell.exe",
  [
    "-NoProfile",
    "-NonInteractive",
    "-Command",
    "Start-Process 'https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm'",
  ],
  { detached: true, stdio: "ignore" },
);

child.unref();
console.log("Página oficial da extensão Playwright MCP aberta no navegador padrão.");
