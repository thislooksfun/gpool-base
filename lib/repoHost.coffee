{CompositeDisposable} = require 'atom'
updater               = require './statusUpdater'
{Directory}           = require 'pathwatcher'
pathMod               = require 'path'

# Home of all the repository and filesystem based logic
module.exports =
class RepoHost
  # Allow for creation of this class - intentionally empty
  constructor: ->
    
  
  # Initalizes all the logic
  start: (@root, @emitter, onDone) ->
    @getRootDir().getSubdirectory(".gpl").exists().then (exists) =>  # Check if there is a directory at '[root]/.gpl'
      @_beginLoad(onDone) if exists                                   # If there is, then start the loading process
  
  
  # Shuts down everything
  stop: ->
    @subscriptions?.dispose()  # Cancels subscriptions
    updater.deinit()           # Discards the statusUpdater
    #TODO more?
  
  
  # Begins the actual logic
  _beginLoad: (finished) ->
    @collectRepos =>  # Get all the repos specified in '.gpl/gpl_manifest.json'
      updater.init @, @root  # Once that's done, start the statusUpdater
      @scanAll(true).then =>  # Scan a first time to initalize everything, then...
        @scanAll().then =>    # Scan a second time to read directory status, then...
          updater.registerExpandListeners()  # Attach trackers to all directories
          finished?()                        # execute the callback, if there is one
  
  
  # Scan all files in the current project, asyncronously
  # Returns a promise that resolves when all files have been scanned
  scanAll: (isInit) ->
    updater.ignoreDotRepo()                                # Set '.gpl' and '.gpl/*' to show as ignored
    promise = new Promise (resolve, reject) =>             # Create a new promise
      for dir, repo of @_repos                             # For every loaded repo...
        @_crawl(new Directory(dir), repo, isInit ? false)  #   Crawl through the directory associated with it
      resolve()                                            # Resolve when done
    
    return promise  # Return the promise created above
  
  
  # Crawl through the specified repo
  _crawl: (item, repo, isInit) ->
    updater.updateItem(item, repo)  # Update this item
    
    if isInit && item.isFile()   # If 'isInit' and if the item is a file, then...
      repo.isPathNew(item.path)  #   Force a repo check to make sure the repo object is loaded properly (weird stuff happens without this)
    
    if item.isDirectory()                 # If this item is a directory, then...
      for entry in item.getEntriesSync()  #   For each item in this directory...
        @_crawl entry, repo, isInit       #     Crawl into it
  
  
  # Get the repository associated with this path
  getRepoForPath: (path) ->
    return null unless path?  # If no path was given, return null
    
    for dir, repo of @_repos                 # For each item in the '@_repos' assoc array...
      return repo if path.indexOf(dir) > -1  #   Return if the path matches
      
    return null  # If no repo was found, return null
  
  
  # The assoc array of the repos
  _repos: {}
  
  # Find and collect all repositories specified in '.gpl/gpl_manifest.json'
  collectRepos: (cb) ->
    @subscriptions?.dispose()                 # Throw away the old subscriptions
    @subscriptions = new CompositeDisposable  # Create a new subscriptions object, since we threw away the last one
    
    mnfst = @getRootDir().getSubdirectory(".gpl").getFile("gpl_manifest.json")  # Get the manifest file
    
    done = =>  # Group a couple items to execute once all collectors are finished
      @emitter.emit "repo-list-change"  # Fire the 'repo-list-change' event
      cb()                              # Execute the callback
    
    mnfst.read(false).then (contents) =>  # Read the manifest file, then...
      json = JSON.parse(contents)
      cnt = json.repositories.length  # Store how many repos we need to search through, to allow for async callbacks
      dec = -> done() if --cnt <= 0      # Create a method to tell us how many async processes have finished
      
      for repo in json.repositories                           # For each project...
        abspth = pathMod.join(@getRootDir().path, repo.path)   #   Get the absolute path
        dir = new Directory(abspth)                              #   Get the directory for said path
        atom.project.repositoryForDirectory(dir).then (repoObj) =>  #   Create a repo for the speficied directory
          if repoObj?                                                                                               # If the repo obj exists, then...
            @_repos[pathMod.dirname(repoObj.path)] = repoObj                                                        #   Add the repo to the repo list
            @subscriptions.add repoObj.onDidChangeStatus   => @scanAll().then => updater.registerExpandListeners()  #   Start tracking single file changes
            @subscriptions.add repoObj.onDidChangeStatuses => @scanAll().then => updater.registerExpandListeners()  #   Start tracking multiple file changes
          
          dec()  # Callback to say this collector is done

  
  # Gets the root directory of the first project
  getRootDir: -> atom.project.getDirectories()[0]