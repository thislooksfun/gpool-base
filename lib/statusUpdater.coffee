{$}                   = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
pathMod               = require 'path'

# This module is used to update the file states in the tree view pane
module.exports =
  
  # Used to set the '@host' and '@treeRoot' variables
  init: (@host, @treeRoot) -> # empty
  
  # Cleans up everything
  deinit: ->
    @subscriptions?.dispose()  # Throw away any subscriptions
    @clearStatuses @treeRoot   # Clear the statuses in the tree view
  
  
  # Clear all the status for this directory and all under it
  clearStatuses: (item) ->
    return unless item?     # Return if 'item' is 'null' or 'undefined'
    @setStatus(item, null)  # Clear the state of 'item'
    
    return unless item.entries?                # Return if there aren't any subdirectories to search through
    @clearStatuses v for k, v of item.entries  # Call '@clearStatuses' on each sub item
  
  
  # Subscribe to folder expansion
  registerExpandListeners: ->
    @subscriptions?.dispose()                 # Clear the current subscriptions to prevent duplicates (TODO: better way of doing this?)
    @subscriptions = new CompositeDisposable  # Make a new subscriptions object, since we threw away the old one
    @registerExpandListenersInDir @treeRoot   # Register listeners, starting at the root
  
  
  # Registers listeners for this directory and all under it
  registerExpandListenersInDir: (dir) ->
    @subscriptions.add dir.onDidAddEntries =>             # Register listener for new files being created under this folder - mainly used here to check if it was opened
      @host.scanAll().then => @registerExpandListeners()  # Scan again to see if any of the newly exposed files have statuses, then re-register in case there are any new folders (TODO: better logic here?)
    
    for k, v of dir.entries                          # loop through sub-directories
      @registerExpandListenersInDir v if v.entries?  # call '@registerExpandListenersInDir' on each sub directory, ignoring the files
  
  
  # Set the state of '[root]/.gpl' and all it's children to be 'ignored'
  ignoreDotRepo: ->
    end = @traverseTree @treeRoot, pathMod.join(@treeRoot.path, ".gpl")  # Get the '.gpl' folder element
    @ignoreAllIn end if end?                                              # Call '@ignoreAllIn' on this directory, if it exists
  
  
  # Ignore all files in, and including, this directory
  ignoreAllIn: (dir) ->
    @setStatus(dir, "ignored")  # Set directory state to be ignored
    
    for k, v of dir.entries               # Loop through the children
      if v.entries? then @ignoreAllIn v   # If it's a folder, loop through it too
      else @setStatus(v, "ignored")       # If it's a file, just ignore it
  
  
  # Update the status of 'item' (can be either a {File} or a {Directory}) in 'repo'
  updateItem: (item, repo) ->
    return unless item?                                 # Return if item is 'null' or 'undefined'
    repo = @host.getRepoForPath item.path unless repo?  # If 'repo' is 'null' or 'undefined', get the repo for the given path
    if item.isFile() then @updateFile item, repo        # If the item is a file, then update it as a file
    else @updateDir item, repo                          # Otherwise, update it as a directory
  
  
  # Updates the status of a {File} in 'repo'
  updateFile: (file, repo) ->
    return unless file?                                 # Abort if 'file' is 'null' or 'undefined'
    repo = @host.getRepoForPath file.path unless repo?  # If 'repo' is 'null' or 'undefined', then attempt to get the proper instance
    end = @traverseTree @treeRoot, file.path            # Get node accocoated with this file
    return unless end?                                  # If the node is 'null' or 'undefined', then there is no point in continuing
    
    unless repo?             # If 'repo' is still 'null' or 'undefined' then...
      @setStatus(end, null)  # Clear the status of this file
      return                 # Return - no point sticking around
    
    newStatus = null                                         # Start off with the new status being cleared
    newStatus = "modified" if repo.isPathModified file.path  # If the file was modifed, then set the state to 'modified'
    newStatus = "added"    if repo.isPathNew      file.path  # If the file is new, then set the state to 'added'
    newStatus = "ignored"  if repo.isPathIgnored  file.path  # If the file is ignored, then set the state to 'ignored'
    
    @setStatus(end, newStatus)  # Set the status of the node to the result of the above block
  
  
  # Updates the status of a {Directory} in 'repo'
  updateDir: (dir, repo) ->
    return unless dir?                                 # Abort if 'dir' is 'null' or 'undefined'
    repo = @host.getRepoForPath dir.path unless repo?  # If 'repo' is 'null' or 'undefined', then attempt to get the proper instance
    end = @traverseTree @treeRoot, dir.path            # Get node accocoated with this directory
    return unless end?                                 # If the node is 'null' or 'undefined', then there is no point in continuing
    
    unless repo?             # If 'repo' is still 'null' or 'undefined' then...
      @setStatus(end, null)  #   Clear the status of this file
      return                 #   Return - no point sticking around
    
    if pathMod.dirname(repo.path) == end.path
      item = $("span[data-path='"+end.path+"']")[0]
      item.classList.remove("icon-file-directory")
      item.classList.add("icon-repo")
    
    status = repo.getDirectoryStatus dir.path                 # Get the state of this directory
    newStatus = null                                          # Start off with the new status being cleared
    newStatus = "modified" if repo.isStatusModified status    # If the directory was modifed, then set the state to 'modified'
    newStatus = "added"    if repo.isStatusNew      status    # If the directory is new, then set the state to 'added'
    newStatus = "ignored"  if repo.isPathIgnored    dir.path  # If the directory is ignored, then set the state to 'ignored'
    
    @setStatus(end, newStatus)  # Set the status of the node to the result of the above block
  
  
  # Set the status of the given item
  setStatus: (item, state) ->
    return if item.status == state                 # There's no point in going further ff the new status is the same as the old one
    item.status = state                            # Set the new status
    item.emitter.emit("did-status-change", state)  # Fire an event to let the display know to re-render this item
  
  
  # Gets an element relative to the root dir, or 'null' if that item isn't visible
  traverseTree: (tree, dest) ->
    rel = pathMod.relative(tree.path, dest)  # The relative path to find
    parts = rel.split(pathMod.sep)           # Each step of the relative path
    
    next = tree               # Start off with 'next' being equal to the root of the tree
    for p in parts            # For each step of the path...
      next = next.entries[p]  #   Set 'next' to be the item in the existing 'next' with the name 'p'
      break unless next?      #   Abort the loop if 'next' is 'null' or 'undefined'
    
    return next  # Return 'next'