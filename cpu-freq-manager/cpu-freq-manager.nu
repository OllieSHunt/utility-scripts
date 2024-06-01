#!/usr/bin/env nu

# A small utility that adjusts the CPU frequency governor.
# 
# Useful info:
# https://wiki.archlinux.org/title/CPU_frequency_scaling
def main [] {
  nu $env.CURRENT_FILE --help
}

# Lists the frequency governor for all CPUs.
def 'main status' [] {
  get_governors
}

# CPU frequency adjusts itself automatily. This is the default.
# 
# Sets the CPU frequency governor to `schedutil`.
def 'main auto' [] {
  do_if_admin {
    set_governors `schedutil`
  }
}

# This runs the CPU at its maximum frequency.
# 
# Sets the CPU frequency governor to `performance`.
def 'main high' [] {
  do_if_admin {
    set_governors `performance`
  }
}

# This runs the CPU at its minimum frequency.
# 
# Sets the CPU frequency governor to `powersave`.
def 'main low' [] {
  do_if_admin {
    set_governors `powersave`
  }
}

# Sets the CPU frequency governor to any value you want.
def 'main custom' [governor: string] {
  do_if_admin {
    set_governors $governor
  }
}

#### UTILITY FUNCTIONS FOR USE INSIDE THIS SCRIPT ONLY ####

# Gets the frequency governor for all CPUs.
# Returns a list.
def get_governors [] {
  (
    # For each CPU...
    glob '/sys/devices/system/cpu/cpu<[0-9]:1,9>'
    | sort
    | each { |cpu|
        $cpu | path join 'cpufreq/scaling_governor' | open
      }
  )
}

# Sets the frequency governor for all CPUs.
def set_governors [governor: string] {
  (
    # For each CPU...
    glob '/sys/devices/system/cpu/cpu<[0-9]:1,9>'
    | each { |cpu| (
          # Save $governor to this CPU's scaling_governor file.
          $governor
          | save --force (
            $cpu | path join 'cpufreq/scaling_governor'
          )
        )
      }
  )
  | ignore # Ignore the empty list this returns.
}

# Run a closure only if this script has admin privileges.
def do_if_admin [action: closure] {
  if (is-admin) {
    do $action
  } else {
    error make --unspanned {
      msg: 'Admin privileges required.',
    }
  }
}
