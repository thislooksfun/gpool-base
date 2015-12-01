pathMod  = require 'path'

# Override functions to allow for branch/status tracking in bottom right
module.exports =
class GraphicsOverride
  # Constructor - sets the @host and @gitItem properties
  constructor: (@host, @gitItem) ->
  
  # Wrapper for @_overrideRepoFunctions
  override: -> @_overrideRepoFunctions()
  
  # Wrapper for @_restoreRepoFunctions
  restore: -> @_restoreRepoFunctions()
  
  # Overrides 'getRepositoryForActiveItem' and 'updateBranchText' in 'status-bar.git' with custom logic
  _overrideRepoFunctions: ->
    @_replaceFunc "getRepositoryForActiveItem", =>  # Replaces the 'getRepositoryForActiveItem' function
      path = @gitItem.getActiveItemPath()                        # Get the path for the active item
      return if path? then @host.getRepoForPath(path) else null  # Get the repository associated with that path
    
    @_replaceFunc "updateBranchText", (repo) =>  # Replaces the 'updateBranchText' function
      @gitItem.branchArea.style.display = 'none'  # Hide the branch display
      
      if @gitItem.showBranchInformation()                              # If we should show the branch information, then...
        head = repo?.getShortHead(@gitItem.getActiveItemPath()) or ''  #   Set 'head' to the active path, if it exists. If not, set it to ''
        if head                                                        #   If 'head' isn't ''...
          rootPath = @host.getRootDir().path                           #     Get the root path of this project
          repoLocation = pathMod.dirname(repo.path)                    #     Get the absolute directory the repo is located in
          repoLoc = pathMod.relative(rootPath, repoLocation)           #     Get the relative location between 'rootPath' and 'repoLocation'
          @gitItem.branchLabel.textContent = "#{repoLoc}/#{head}"      #     Set the branch display text (TODO: maybe split this up into it's own 'area', complete w/ repo icon?)
          @gitItem.branchArea.style.display = ''                       #     Unhide the branch display
    
    @gitItem.update()  # Force update to fully incorperate the new functions
  
  
  # The assoc array of replaced functions
  _funcs: {}
  
  # Replaces 'status-bar.git.[name]' with 'newFunc'
  _replaceFunc: (name, newFunc) ->
    @_funcs[name] = @gitItem[name]  # Backup old function...
    @gitItem[name] = newFunc        # ...and replace it with a shiny new one!
    
  # Restores all the original functions
  _restoreRepoFunctions: ->
    @gitItem[k] = v for k, v of @_funcs  # Restore each function
    @gitItem.update()                    # Force update to fully incorperate the new functions