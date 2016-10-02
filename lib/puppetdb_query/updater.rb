require_relative "logging"

module PuppetDBQuery
  # update nodes data from source to destination
  class Updater
    include Logging

    attr_reader :source
    attr_reader :destination

    def initialize(source, destination)
      @source = source
      @destination = destination
    end

    # update by deleting missing nodes and iterating over all nodes and
    # update or insert facts for each one
    #
    # 335.6 seconds: update time for 1561 nodes
    def update1
      logger.info "update1 started (full update)"
      tsb = Time.now
      source_nodes = source.nodes
      destination_nodes = destination.nodes
      delete_missing(destination_nodes, source_nodes)
      errors = false
      source_nodes.each do |node|
        begin
          destination.node_update(node, source.node_facts(node))
        rescue
          errors = true
          logging.error $!
        end
      end
      tse = Time.now
      logger.info "update1 updated #{source_nodes.size} nodes in #{tse - tsb}"
      destination.meta_fact_update("update1", tsb, tse) unless errors
    end

    # update by deleting missing nodes and get a complete map of nodes with facts
    # and update or insert facts for each one
    #
    # 166.4 seconds: update time for 1561 nodes
    def update2
      logger.info "update2 started (full update)"
      tsb = Time.now
      source_nodes = source.nodes
      destination_nodes = destination.nodes
      delete_missing(destination_nodes, source_nodes)
      errors = false
      complete = source.facts
      complete.each do |node, facts|
        begin
          destination.node_update(node, facts)
        rescue
          errors = true
          logging.error $!
        end
      end
      tse = Time.now
      logger.info "update2 updated #{source_nodes.size} nodes in #{tse - tsb}"
      destination.meta_fact_update("update2", tsb, tse) unless errors
    end

    # update by deleting missing nodes and getting a list of nodes
    # with changed facts, iterate over them and update or insert facts for each one
    #
    # update time depends extremly on the number of changed nodes
    def update3(last_update_timestamp)
      logger.info "update3 started (incremental)"
      tsb = Time.now
      source_nodes = source.nodes
      destination_nodes = destination.nodes
      delete_missing(destination_nodes, source_nodes)
      errors = false
      modified = source.nodes_update_facts_since(last_update_timestamp)
      modified.each do |node|
        begin
          destination.node_update(node, source.node_facts(node))
        rescue
          errors = true
          logging.error $!
        end
      end
      tse = Time.now
      logger.info "update3 updated #{modified.size} nodes in #{tse - tsb}"
      destination.meta_fact_update("update3", tsb, tse) unless errors
    end

    def update_node_properties
      logger.info "update_node_properties started"
      tsb = Time.now
      source_node_properties = source.node_properties
      destination.node_properties_update(source_node_properties)
      tse = Time.now
      logger.info "update_node_properties updated #{source_node_properties.size} nodes in #{tse - tsb}"
      destination.meta_node_properties_update(tsb, tse)
    end

    private

    def delete_missing(destination_nodes, source_nodes)
      missing = destination_nodes - source_nodes
      missing.each do |node|
        destination.node_delete(node)
      end
      logger.info "  deleted #{missing.size} nodes"
    end
  end
end
