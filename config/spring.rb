if !Rails.env.production? && !Rails.env.dev?
  Spring.watch(
    ".ruby-version",
    ".rbenv-vars",
    "tmp/restart.txt",
    "tmp/caching-dev.txt"
  )

  Spring.watch_interval = 0.7
end
