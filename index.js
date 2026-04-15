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
      pattern: "**/*",
      options: { cwd: "src", ignore: ["*.tmp", "*.TMP"] },
    },
  ],
  modTxtOptions: {
    autoload: {
      [`!DbgUtils`]: "DbgUtils.gd",
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
