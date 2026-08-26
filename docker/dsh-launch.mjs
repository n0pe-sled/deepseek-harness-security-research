// Keep pnpm's source-workspace module resolution while making the mounted
// campaign the process and new-session working directory.
process.chdir(process.env.DSH_CAMPAIGN_ROOT ?? '/workspace')
await import('/opt/deepseek-harness/apps/cli/src/bin.ts')
