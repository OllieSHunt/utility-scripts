#!/usr/bin/env nu

use std assert

let offline_web = {
  website_dir: $'($env.HOME)/.offline-web'
  user_agent: 'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0'
  wait_time: 1
  rate_limit: '20k'
}

# A nushell script designed to greatly simplify wget for one specific use case.
# 
# This command allows you to make offline clones of indevidual webpages or copy
# whole websites for offline viewing.
def main [] {
  nu $env.CURRENT_FILE --help
}

# Download a website.
def 'main clone' [
  url: string,      # URL to the website/webpage to download.
  name?: string,    # What to save the website as.
  --full-site (-f), # Download the full website instead of just one page.
  --other (-o),     # Fetch other websites when using `--full-site`.
  --continue (-c),  # (WIP) Continue download where it was left off.
  --parent (-p),    # Enable ascending to the parent directory.
] {
  #### NOT YET IMPLEMENTED CHECKS ####

  if $continue {
    error make --unspanned {
      msg: '--continue is not yet implemented.',
    }
  }

  #### SETUP ####

  # This sets $name to the same as $url if $name is empty.
  let name = (
    if ($name == null) {
      $url
    } else {
      $name
    }
  )

  # Where to download files to
  let download_dir = ($offline_web.website_dir | path join 'downloads' | path join $name)

  # The arguments that will be passed to wget
  let wget_args = (
    [
        --user-agent=($offline_web.user_agent)
        --wait=($offline_web.wait_time)
        --random-wait
        --limit-rate=($offline_web.rate_limit)
        --page-requisites
        --adjust-extension
        --convert-links
        --directory-prefix=($download_dir)
        (if $full_site { '--mirror' } else { '' })
        (if $other { '--span-hosts' } else { '' })
        (if $parent { '' } else { '--no-parent' })
    ]
    | each { |arg| if ($arg != '') { $arg } } # Remove all empty strings
  )

  #### CHECKS ####

  # Check if this website has already been downloaded
  if ($download_dir | path exists) {
    (
      print
        $'There is already a website saved under the name "($name)".'
        'Do you want to overwrite it? (The old version will be backed up)'
    )

    # Loop untill user answers ether y or n.
    loop {
      let user_input = (input --numchar 1 '(y/N): ' | str downcase)

      if ($user_input == 'y') {
        print 'Overwirting...'

        let backup_dir = ([ $download_dir '-BACKUP' ] | str join)

        # Delete old backup
        rm -rf $backup_dir

        # Make backup new backup
        mv $download_dir $backup_dir
        print $'Created backup in: ($backup_dir)'

        # Delete the old symlink for this website
        try {
          rm ($offline_web.website_dir | path join 'symlinks' | path join $name)
        } catch {
          print "Tried to delete old symlink but failed."
        }

        break
      } else if ($user_input == 'n') or ($user_input == '') {
        print 'Canceled'
        return
      }
    }
  }

  #### EXECUTING COMMANDS ####

  # Make output directorys
  mkdir $download_dir
  mkdir ($offline_web.website_dir | path join 'symlinks')
  
  # Run wget
  wget ...($wget_args) $url

  # Create symlink
  link_website $name
}

# Delete a downloaded website.
def 'main delete' [
  name: string, # The name of the downloaded website to delete.
] {
  (
    rm -rf
      ($offline_web.website_dir | path join 'symlinks' | path join $name)
      ($offline_web.website_dir | path join 'downloads' | path join $name)
  )
}

# Open a website using firefox.
def 'main open' [
  name?: string, # The name of the downloaded website to view.
] {
  # Select path of the site
  let out_dir = if ($name != null) {
    ($offline_web.website_dir | path join 'symlinks' | path join $name)
  } else {
    # Get all websites
    let all_sites = (ls --short-names ($offline_web.website_dir | path join 'symlinks') | each {|file| $file.name })

    # Ask the user which one they want to open
    let name = ($all_sites | input list --fuzzy 'Search:')

    ($offline_web.website_dir | path join 'symlinks' | path join $name)
  }

  # If the path exists: open firefox, else: error
  if ($out_dir | path exists) {
    firefox $out_dir
  } else {
    error make --unspanned {
      msg: $'"($out_dir | path basename)" is not downloaded.',
    }
  }
}

# List all downloaded webistes.
def 'main list' [] {
  ls ($offline_web.website_dir | path join 'symlinks') | each {|out_dir|
    ($out_dir.name | path basename)
  }
}

# Resore a backup of a website
def 'main restore' [
  name?: string, # The name of the website.
] {
  # Select path of the site
  let backup_dir = if ($name != null) {
    [ ($offline_web.website_dir | path join 'symlinks' | path join $name) '-BACKUP' ] | str join
  } else {
    # Get all websites that end with "-BACKUP"
    let all_sites = (ls --short-names ($offline_web.website_dir | path join 'downloads') | each {|file|
      let file_name = $file.name

      if ($file_name | str ends-with '-BACKUP') {
        $file_name
      }
    })

    # Make sure there is at least one backup to restore
    if ($all_sites | length) == 0 {
      error make --unspanned {
        msg: 'There are no backups to restore.',
      }
    }

    # Ask the user which site they want to restore
    let name = ($all_sites | input list --fuzzy 'Search:')

    ($offline_web.website_dir | path join 'downloads' | path join $name)
  }

  # This is just $backup_dir with '-BACKUP' removed
  let website_dir = ($backup_dir | str replace --regex '-BACKUP$' '')
  let website_name = ($website_dir | path basename)

  # Error checking
  assert ($website_dir != $backup_dir)

  # If the path exists: restore backup, else: error
  if ($backup_dir | path exists) {
    print 'Removing old website...'
    rm -rf $website_dir

    print 'Restoring backup...'
    mv $backup_dir $website_dir

    print 'Recreating Link...'
    link_website $website_name
  } else {
    error make --unspanned {
      msg: $'Can not find backup of "($website_name)".',
    }
  }
}

# This uses `sshfs` to mount a remote server's directory of downloaded websites
# over the top of this machine's.
def 'main mount' [
  destination: string, # [user@]host
  remote_dir: path = "/home/guest/.offline-web", # The path to the server's downloaded websites.
] {
  try {
    # Mount the remote file system.
    sshfs $'($destination):($remote_dir)' $offline_web.website_dir
  } catch {
    error make --unspanned {
      msg: $'sshfs command failed, this could be becuase there is something already mounted at ($offline_web.website_dir)',
    }
  }

  # Check to see if the newly mounted direcotry has the correct folders in.
  if (not ($offline_web.website_dir | path join 'symlinks' | path exists)
    and not ($offline_web.website_dir | path join 'symlinks' | path exists)) {

    # Attempt to unmount the directory, ignore any errors.
    do -isp { nu $env.CURRENT_FILE umount }

    error make --unspanned {
      msg: 'Directory does not seem to contain the correct files.',
    }
  }
}

# Undoes the effects of the `mount` subcommand.
def 'main umount' [] {
  umount $offline_web.website_dir
}

# Checks whether there is a remote server's downloaded websites mounted over
# the top of this computer's downloaded websites. (See the `mount` subcommand
# for more info)
def 'main status' [] {
  try {
    mountpoint $offline_web.website_dir | ignore
    print "Remote server mounted."
  } catch {
    print "No remote server mounted."
  }
}

#### UTILITY FUNCTIONS ####

# Creates a symlink to one of the html files in the website.
def link_website [name: string] {
  # Where the website is located
  let website_dir = ($offline_web.website_dir | path join 'downloads' | path join $name)

  # Get all html files from this website
  let all_html = (glob ($website_dir | path join **) | find .html)

  # Which html file to link to
  let html_path = match ($all_html | length) {
    0 => {
      # Delete the website and throw an error.
      nu $env.CURRENT_FILE delete $name

      error make --unspanned {
        msg: 'Unable to find any .html file in the downloaded website.',
      }
    }

    1 => {
      # There is only one html file, so just return that.
      ($all_html | first)
    }

    _ => {
      # Ask the user which html file they want to use.
      (
        print
          'Several html files where found in the downloaded website.'
          'Which one would you like to be opened when you use the `open` subcommand?'
      )

      ($all_html | input list --fuzzy 'Search:')
    }
  }

  # Creates the symlink
  (
    ln -sf
      $html_path                                                          # Original
      ($offline_web.website_dir | path join 'symlinks' | path join $name) # Destination
  )
}
