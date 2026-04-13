import modBuilder from "rtv-modbuilder";
import packageInfoJson from "./package.json" with { type: "json" };

const modName = packageInfoJson.displayName;

await modBuilder({
  /**
   * Where the mod builder should look for files to include in the MOD, and where to output the built MOD.
   * This is NOT necessarily the same as the root of your project, but it can be if you want it to be.
   */
  projectRoot: "",
  outDir: "build",

  /**
   * Information about the mod, which will be used to fill out the mod.txt file and other metadata.
   * The id should be unique to your mod, and is usually the same as the package name in package.json.
   * The name is the display name of the mod, and can be different from the id.
   * The version should follow semantic versioning, and is used to determine if updates are available for the mod.
   *
   * All of these can be pulled from the package.json file, but you can also hardcode them if you want to.
   */
  packageInfo: {
    id: packageInfoJson.name,
    name: modName,
    version: packageInfoJson.version,
  },

  /**
   * Globs to include in the mod.
   * The glob typing comes directly from Archiver, so you can use any pattern that Archiver supports.
   * Providing the cwd is optional, but recommended to avoid accidentally including files you don't want in the mod.
   * If you don't provide a cwd, the pattern will be relative to the projectRoot.
   */
  globs: [
    {
      pattern: "**/*", // any files in the cwd
      options: { ignore: ["**/do_not_include.txt"], cwd: "src" }, // include all files in src except do_not_include.txt
    },
  ],

  /**
   * The mod.txt file is required for the mod to work.
   * This helps fill out the mod.txt file for you, so you don't have to worry about formatting it correctly.
   */
  modTxtOptions: {
    autoload: { [`${modName}Main`]: "Main.gd" },
    author: "Theta",
    priority: 0,
  },

  /**
   * Misc options for the mod builder.
   */
  options: {
    includeVersionInName: true,
    verbose: true,
  },
}).catch((err) => {
  console.error("Error building mod:", err);
});
