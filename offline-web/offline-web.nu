#!/usr/bin/env nu


#### GLOBAL VARIABLES ####


# Offline web's main direcotry.
let WEBSITE_DIR = $'($env.HOME)/.offline-web'

# Where websites are downloaded to.
let DOWNLOAD_DIR = $'($WEBSITE_DIR)/downloads'

# Symlinks to the websites' index.html (or equivilent).
let OUTPUT_DIR = $'($WEBSITE_DIR)/output'

# The user agent that wget will use.
let USER_AGENT = 'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0'

# The time to wait between requests.
let WAIT_TIME = 1

# Limit download speed.
let RATE_LIMIT = '20k'


#### MAIN FUNCTION AND SUBCOMMANDS ####


# A nushell script designed to greatly simplify wget for one specific use case.
# 
# This command allows you to make offline clones of indevidual webpages or copy
# whole websites for offline viewing.
def main [] {
  # Show help info
  nu $env.CURRENT_FILE --help
}



# Download a website.
def 'main clone' [
  url: string,      # URL to the website/webpage to download.
  name: string,     # What to save the website as.
  --full-site (-f), # Download the full website instead of just one page.
  --other (-o),     # Fetch other websites when using `--full-site`.
  --parent (-p),    # Enable ascending to the parent directory.
  # TODO: --continue (-c),  # Continue download where it was left off.
] {
  print "NOTE: In the event that a download fails half way through, you can use\n      the "clean" subcommand to clean remove the half downloaded website.\n"

  #### SETUP VAIRABLES ####

  # Where to download files to
  let download_dir = (get_download_dir $name)
  let symlink_file = (get_output_file $name)

  # The arguments that will be passed to wget
  let wget_args = (
    [
        --user-agent=($USER_AGENT)
        --wait=($WAIT_TIME)
        --random-wait
        --limit-rate=($RATE_LIMIT)
        --page-requisites
        --adjust-extension
        --convert-links
        --directory-prefix=($download_dir)
        (if $full_site { '--mirror' } else { '' })
        (if $other { '--span-hosts' } else { '' })
        (if $parent { '' } else { '--no-parent' })
    ]
    | each { if ($in != '') { $in } } # Remove all empty strings
  )

  #### CHECKS ####

  # Check if this website has already been downloaded
  if ($download_dir | path exists) or ($symlink_file | path exists) {
    error make --unspanned {
      msg: $"There is already a website saved under the name ($name).\nUse the \"update\" subcommand to update it or the \"delete ($name)\"\nsubcommand to remove it.",
    }
  }

  #### EXECUTING COMMANDS ####

  # No changes are made to files before this point in the function.
  # If one of the following commands fails, then the website will be deleted.
  # This is to prevent half downloaded websites.
  # Make output directorys
  mkdir $download_dir

  # Save things that will be passed to wget so that they can be used again
  # when updating the website later.
  $wget_args | save ($download_dir | path join 'wget_args.txt')
  $url | save ($download_dir | path join 'url.txt')

  # Try to run wget. The try...catch is needed because wget can sometimes exit
  # with error codes, even when mostly sucessfull.
  try {
    wget ...($wget_args) $url
  } catch {|e|
    print 'wget exited with a non-zero exit status. This could meen that it was unsecessfull, but not always.'
    print $'wget exit code: ($env.LAST_EXIT_CODE)'
    print $e
    print "\n"
  }
  print 'wget finished.'

  # Create a symlink to the new website.
  link_website $name
  print 'Created symlink.'

  print $'Finished: Offline clone of ($url) saved under the name ($name).'
}


# Delete a downloaded website.
def 'main delete' [
  name?: string, # The name of the downloaded website to delete.
] {
  # If $name is null, then ask the user which website they want to delete.
  let name = if ($name == null) {
    select_from_list (get_website_names) "Select a website to delete."
  } else {
    $name
  }

  delete_website $name

  print $'($name) has been deleted.'
}


# Open a website using firefox.
def 'main open' [
  name?: string, # The name of the downloaded website to view.
] {
  # Gets the path to the file to pass to firefox.
  let symlink_path = get_output_file (
    if $name == null {
      select_from_list (get_website_names) 'Please select a website to open.'
    } else {
      $name
    }
  )

  firefox $symlink_path
  print $'($symlink_path | path basename) opened in firefox.'
}


# List all downloaded webistes.
def 'main list' [] {
  return (get_website_names)
}


# Update a downloaded website.
def 'main update' [
  name?: string, # Name of the website to update.
] {
  # Ask the user what website to update if they did not specify one.
  let name = (
    if ($name == null) {
      select_from_list (get_website_names) 'Please select a website to update.'
    } else {
      $name
    }
  )

  # Find where the website was downloaded to.
  let download_dir = get_download_dir $name

  # Fetch the arguments that were originaly used to call wget with for this
  # website. Then append --timestamping to that list.
  let wget_args = try {
    (
      open ($download_dir | path join 'wget_args.txt')
      | split row --regex '\n'        # Turn string into list.
      | each { if ($in != '') {$in} } # Remove any empty list items.
      | append '--timestamping'       # Add --timestamping argument.
    )
  } catch {|e|
    print $'Error message for debuging: ($e.msg)'
    print "\n"
    
    error make --unspanned {
      msg: $"Problem finding ($name). Is this website downloaded?.",
    }
  }

  # Get the url of this website.
  let url = open ($download_dir | path join 'url.txt')

  # Run wget and create a symlink to the new website.
  wget ...($wget_args) $url
  link_website $name
}


# Remove half downloaded websites.
#
# This command finds and removes any websites that have been downloaded but
# don't show using the `list` subcommand. This can happen if you manualy stop
# a download half way through.
def 'main clean' [] {
  # Get all symlinks in $OUTPUT_DIR
  let symlinks = (ls --short-names $OUTPUT_DIR).name

  # Get all folders in $DOWNLOAD_DIR
  let download_folders = (ls --short-names $DOWNLOAD_DIR).name

  # Find symlinks that don't have a coresponding download folder.
  $symlinks | each {|symlink|
    if (($download_folders | find $symlink | length) == 0) {
      # Delete lonely symbolic link.
      let path_to_delete = ($OUTPUT_DIR | path join $symlink)
      print $'Deleting: ($path_to_delete)'
      rm -rf $path_to_delete
    }
  }

  # Find download folders that don't have a coresponding symlink.
  $download_folders | each {|download_folder|
    if (($symlinks | find $download_folder | length) == 0) {
      # Delete lonely download folder link.
      let path_to_delete = ($DOWNLOAD_DIR | path join $download_folder)
      print $'Deleting: ($path_to_delete)'
      rm -rf $path_to_delete
    }
  }

  print 'Finished cleanup.'
}

# # Create a backup of a downloaded website.
# def 'main backup' [name?: string] {
#   print 'TODO'
# }


# # Resore a backup of a website
# def 'main restore' [
#   name?: string,       # The name of the website.
#   backup_number?: int, # 1 is the most resent backup. The higher the number, the older the backup.
# ] {
#   print 'TODO'
# }


# This uses `sshfs` to mount a remote server's directory of downloaded websites
# over the top of this machine's.
#
# This command assumes that the downloaded websites are in the same location
# on the remote machine as they are on this machine, but with the user name
# switched.
def 'main mount' [
  destination: string, # user@host
] {
  # Split the input using "@" as a seperator.
  let split_destination = $destination | split column '@'

  # Check destination is formated correctly.
  if ($split_destination | columns | length) != 2 {
    error make --unspanned {
      msg: 'Destination must be in the format: user@host',
    }
  }

  let remote_user = $split_destination.column1.0
  let remote = $split_destination.column2.0

  # Find the remote's $WEBSITE_DIR by replacing $env.USER with $remote_user
  let remote_dir = (
    $WEBSITE_DIR | str replace $'/home/($env.USER)/' $'/home/($remote_user)/'
  )

  # Put together the full address that will be passed to sshfs.
  let full_address = $'($remote_user)@($remote):($remote_dir)'
  print $'Atempting to mount "($full_address)" to "($WEBSITE_DIR)"...'

  # Mount the remote directory using sshfs.
  sshfs -o transform_symlinks $full_address $WEBSITE_DIR

  # Check to see if the newly mounted direcotry has the correct folders in.
  if not (($OUTPUT_DIR | path exists) and ($DOWNLOAD_DIR | path exists)) {
    # Something has gone wrong, unmount the directory and throw an error.
    umount $WEBSITE_DIR

    error make --unspanned {
      msg: 'Directory does not seem to contain the correct files, so it was unmounted.',
    }
  }

  print 'Success!'
}


# Undoes the effects of the `mount` subcommand.
def 'main umount' [] {
  umount $WEBSITE_DIR
}


# Checks whether there is a remote server's downloaded websites mounted over
# the top of this computer's downloaded websites. (See the `mount` subcommand
# for more info)
def 'main status' [] {
  try {
    mountpoint $WEBSITE_DIR | ignore
    print "Remote server mounted."
  } catch {
    print "No remote server mounted."
  }
}


#### MISC FUNCTIONS ####


# Creates a symlink to one of the html files in the website and puts it
# in $OUTPUT_DIR. This will prompt the user to select a file (unless there
# is only one html file).
def link_website [name: string] {
  # Where the website is located
  let download_dir = (get_download_dir $name)

  # Get all html files from this website
  let all_html = (
    (glob ($download_dir | path join **) | find .html)
    | each {
      # Remove the first part of each path to make the output look cleaner.
      $in | str replace ([$download_dir '/'] | str join) ''
    }
  )

  # Deside which html file to symlink
  let html_file = try {
    select_from_list $all_html 'Several html files where found in the downloaded website. Which one would you like to be opened when using the `open` subcommand?'
  } catch {
    error make --unspanned {
      msg: 'Can not make symlink to any html file. This could be because there is no html flies in the downloaded website.',
    }
  }

  # Creates the symlink
  mkdir $OUTPUT_DIR
  ln -sf ($download_dir | path join $html_file) (get_output_file $name)
}


def delete_website [name: string] {
  (
    rm -rf
      (get_output_file $name)
      (get_download_dir $name)
  )
}


# Asks the user to select a string from a from a list of strings.
def select_from_list [
  options: list<any> # Strings to select from.
  prompt: string     # What to ask the user.
]: nothing -> any {
  return (match ($options | length) {
    # No strings to choose from, throw an error
    0 => {
      error make {
        msg: 'No strings in list.',
        label: {
            text: "List must contain at least on string.",
            span: (metadata $options).span
        }
      }
    }

    # Only one string in list, so just use that.
    1 => {
      ($options | first)
    }

    # More than one string in list, ask the user which one they wat to use.
    _ => {
      print $prompt

      mut selection = null
      
      # Keep asking until they choose something.
      # This is needed because the `input list` command will return null if the
      # user presses the esc key.
      while $selection == null {
        $selection = ($options | input list --fuzzy 'Search:')
      }

      $selection
    }
  })
}

# Gets the names of all downloaded websites.
def get_website_names []: nothing -> list<string> {
  return (ls --short-names $OUTPUT_DIR).name
}

# Returns the directory where a website should be downloaded to.
def get_download_dir [name: string]: nothing -> path {
  return ($DOWNLOAD_DIR | path join $name) 
}

# Returns the path where a website's symlink should be.
def get_output_file [name: string]: nothing -> path {
  return ($OUTPUT_DIR | path join $name) 
}
