{requirePackages}              = require 'atom-utils'
{CompositeDisposable, Emitter} = require 'atom'
RepoHost                       = require './repoHost'
GraphicsOverride               = require './graphicIntegrationOverride'
PluginManagement               = require './mixins/plugin-management'

# Use classes to allow 'includeInto' to work
class Main
  # Includes the PluginManagement items into this class - useful for separating chunks of code into separate files
  PluginManagement.includeInto(this)
  
  
  subscriptions: null  # The subscriptions we have
  emitter: null        # The event emitter
  host: null           # The RepoHost instance - used for plugin access
  
  
  # Power up the module
  activate: (state) ->
    @subscriptions = new CompositeDisposable  # Create a new subscriptions object
    
    @subscriptions.add atom.commands.add 'atom-workspace', 'gpool-base:refresh': => @refresh()  # Add the refresh command
    
    @emitter = new Emitter  # Create a new emitter
    
    @host = new RepoHost  # Create the RepoHost instance
    
    requirePackages("tree-view", "status-bar").then ([tree, statusBar]) =>   # Wait for 'tree-view' and 'status-bar' to load before continuing
      @statusBar = statusBar
      
      @_getProjRoot tree
  
  _getProjRoot: (tree) ->
    projRoot = tree.treeView.list[0].querySelector('.project-root')  # Get the root of the tree view
    if projRoot?
      @_finishInit projRoot.directory
    else
      setTimeout (=> @_getProjRoot tree), 200
  
  _finishInit: (root) ->
    @graphics = new GraphicsOverride @host, @statusBar.git  # Create the GraphicsOverride instance
    @host.start root, @emitter, =>  # Start the repo logic
      @graphics.override()          # Initalize the overrides
  
  
  # Executes 'cb' when the list of collected repositories is updated
  onRepoListChange: (cb) ->
    @emitter.on "repo-list-change", cb  # Register 'cb' to be called on the 'repo-list-change' event
  
  
  # Deactivate everything
  deactivate: ->
    @subscriptions.dispose()  # Throw away subscriptions
    @host.stop()              # Clean up logic
    @graphics.restore()       # Restore the functions we replaced
  
  
  # Reload everything except the command subscriptions
  refresh: ->
    @host.stop()         # Shut down the logic
    @graphics.restore()  # Restore the overridden items
    
    tree = atom.packages.getLoadedPackage("tree-view").mainModule          # Get the tree-view module instance
    root = tree.treeView.list[0].querySelector('.project-root').directory  # Get the root of the tree view
    
    @host.start root, =>  # Start the repo logic
      @graphics.override  # Initalize the overrides


module.exports = new Main()  # Set the exports to an new instance