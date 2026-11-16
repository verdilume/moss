export function stdoutIsTty() {
  return globalThis.process?.stdout?.isTTY === true ||
    globalThis.Deno?.stdout?.isTerminal() === true;
}

export function getenv(name) {
  try {
    if (globalThis.Deno) {
      const permission = Deno.permissions.querySync({ name: "env", variable: name });
      return permission.state === "granted" ? Deno.env.get(name) ?? "" : "";
    }
    return globalThis.process?.env?.[name] ?? "";
  } catch {
    return "";
  }
}

export function queryBackground(script) {
  try {
    if (globalThis.Deno) {
      if (Deno.build.os === "windows" || !Deno.stdin.isTerminal()) return "";
      const permission = Deno.permissions.querySync({ name: "run", command: "/bin/sh" });
      if (permission.state !== "granted") return "";
      const output = new Deno.Command("/bin/sh", {
        args: ["-c", "exec 5<>/dev/tty || exit 1; exec 6>&5\n" + script],
        stdout: "piped", stderr: "null",
      }).outputSync().stdout;
      return String.fromCharCode(...output);
    }
    const process = globalThis.process;
    if (process?.platform === "win32" || process?.stdin?.isTTY !== true) return "";
    const spawn = process.getBuiltinModule?.("node:child_process")?.spawnSync;
    const result = spawn?.("/bin/sh", ["-c", "exec 5<&0; exec 6>&3\n" + script], {
      encoding: "latin1", stdio: ["inherit", "pipe", "ignore", 1], timeout: 400,
    });
    return result?.stdout ?? "";
  } catch {
    return "";
  }
}
