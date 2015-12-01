Mixin = require 'mixto'
{CompositeDisposable} = require 'atom'

module.exports =
class PluginManagement extends Mixin

  ### Public ###

  # Returns the {Gpool} service API object.
  provideGpoolServiceV1: -> this

  # Internal: Stores the plugins with their identifying name as key.
  plugins: {}

  # Registers a minimap `plugin` with the given `name`.
  #
  # name - The identifying {String} name of the plugin.
  #        It will be used as activation settings name as well
  #        as the key to unregister the module.
  # plugin - The plugin {Object} to register.
  registerPlugin: (name, plugin) ->
    @plugins[name] = plugin
    
    plugin.gpl_activatePlugin()

  # Unregisters a plugin from the minimap.
  #
  # name - The identifying {String} name of the plugin to unregister.
  unregisterPlugin: (name) ->
    plugin = @plugins[name]
    delete @plugins[name]

    event = {name, plugin}
    # @emitter.emit('did-remove-plugin', event)

  # Toggles the specified plugin activation state.
  #
  # name - The {String} name of the plugin.
  # boolean - An optional {Boolean} to set the activation state of the plugin.
  #           If ommitted the new plugin state will be the the inverse of its
  #           current state.
  togglePluginActivation: (name, boolean=undefined) ->
    plugin = @plugins[name]
    pluginActive = plugin.gpl_isActive()
    
    if boolean or not pluginActive
      plugin.gpl_activatePlugin()
    else
      plugin.gpl_deactivatePlugin()

  # Deactivates all the plugins registered in the minimap package so far.
  deactivateAllPlugins: ->
    plugin.gpl_deactivatePlugin() for name, plugin of @plugins