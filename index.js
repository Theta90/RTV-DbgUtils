import modBuilder from "rtv-modbuilder";
import packageInfoJson from "./package.json" with { type: "json" };

await modBuilder({
  projectRoot: "",
  outDir: "build",
  packageInfo: {
    id: packageInfoJson.name,
    name: packageInfoJson.displayName,
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
    modworkshopID: "56137",
  },
  options: {
    verbose: true,
  },
}).catch((err) => {
  console.error("Error building mod:", err);
});
