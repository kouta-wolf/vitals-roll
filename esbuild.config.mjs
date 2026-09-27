import * as esbuild from "esbuild"

// RAILS_ENV は assets:precompile 経由（Render のデプロイ）で渡ってくる
const production = process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production"

const options = {
  // ワイルドカードにすると app/javascript 直下へ置いた補助ファイル（テスト用のsetup等）まで
  // 別のエントリポイントとして出力されてしまうため、エントリは明示する
  entryPoints: ["app/javascript/application.js"],
  bundle: true,
  format: "esm",
  outdir: "app/assets/builds",
  publicPath: "/assets",
  sourcemap: !production,
  minify: production,
  // これが無いと React の開発用ビルド（警告・デバッグ情報つき）が本番へ載る。
  // 指定するとバンドルが 1.4MB から大幅に縮み、実行時のチェックも外れる。
  define: {
    "process.env.NODE_ENV": JSON.stringify(production ? "production" : "development")
  }
}

if (process.argv.includes("--watch")) {
  const context = await esbuild.context(options)
  await context.watch()
  console.log("esbuild: watching...")
} else {
  await esbuild.build(options)
}
