import modBuilder from "rtv-modbuilder";
import packageInfoJson from "./package.json" with { type: "json" };

const modName = packageInfoJson.displayName;

await modBuilder({
  projectRoot: "",
  outDir: "build",
  packageInfo: {
    id: packageInfoJson.name,
    name: modName,
    version: packageInfoJson.version,
  },
  globs: [
    {
      pattern: "**/*", // any files in the cwd
      options: { cwd: "src", ignore: ["*.tmp", "*.TMP", "**/*.import"] }, // include all files in src except do_not_include.txt
    },
  ],
  modTxtOptions: {
    autoload: {
      [`DbgUtils_LoggerUI`]: "Logger/CustomLoggerUI.tscn",
    },
    author: "Theta",
    priority: -999,
  },
  options: {
    includeVersionInName: true,
    verbose: true,
  },
}).catch((err) => {
  console.error("Error building mod:", err);
});
