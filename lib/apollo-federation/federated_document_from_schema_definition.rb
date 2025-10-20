# frozen_string_literal: true

require 'graphql'
require 'apollo-federation/service'
require 'set'

module ApolloFederation
  class FederatedDocumentFromSchemaDefinition < GraphQL::Language::DocumentFromSchemaDefinition
    FEDERATION_TYPES = [
      '_Any',
      '_Entity',
      '_Service',
    ].freeze
    FEDERATION_QUERY_FIELDS = [
      '_entities',
      '_service',
    ].freeze

    attr_reader :used_directives

    def initialize(*args, **kwargs)
      super
      @used_directives = Set.new
    end

    def build_object_type_node(object_type)
      object_node = super
      if query_type?(object_type)
        federation_fields = object_node.fields.select do |field|
          FEDERATION_QUERY_FIELDS.include?(field.name)
        end
        federation_fields.each { |field| object_node = object_node.delete_child(field) }
      end
      merge_directives(object_node, object_type)
    end

    def build_interface_type_node(interface_type)
      interface_node = super
      merge_directives(interface_node, interface_type)
    end

    def build_union_type_node(union_type)
      union_node = super
      merge_directives(union_node, union_type)
    end

    def build_enum_type_node(enum_type)
      enum_node = super
      merge_directives(enum_node, enum_type)
    end

    def build_enum_value_node(enum_value_type)
      enum_value_node = super
      merge_directives(enum_value_node, enum_value_type)
    end

    def build_scalar_type_node(scalar_type)
      scalar_node = super
      merge_directives(scalar_node, scalar_type)
    end

    def build_input_object_node(input_object_type)
      input_object_node = super
      merge_directives(input_object_node, input_object_type)
    end

    def build_argument_node(argument_type)
      argument_node = super
      merge_directives(argument_node, argument_type)
    end

    def build_field_node(field_type)
      field_node = super
      merge_directives(field_node, field_type)
    end

    def build_type_definition_nodes(types)
      non_federation_types = types.select do |type|
        if query_type?(type)
          # In graphql 2.4+, accessing fields can trigger visibility checks
          # Use schema.get_fields to avoid duplicate name errors
          begin
            fields = schema.get_fields(type).values
            !fields.all? { |field| FEDERATION_QUERY_FIELDS.include?(field.graphql_name) }
          rescue GraphQL::Schema::DuplicateNamesError
            # If there are duplicate names, include the type (it has non-federation fields)
            true
          end
        else
          !FEDERATION_TYPES.include?(type.graphql_name)
        end
      end
      super(non_federation_types)
    end

    private

    def query_type?(type)
      type == schema.query
    end

    def merge_directives(node, type)
      if type.is_a?(ApolloFederation::HasDirectives)
        directives = type.federation_directives || []
      else
        directives = []
      end

      directives.each do |directive|
        @used_directives << directive[:name]
        node = node.merge_directive(
          name: directive_name(directive),
          arguments: build_arguments_node(directive[:arguments]),
        )
      end
      node
    end

    def directive_name(directive)
      if schema.federation_2? && schema.default_link_namespace
        "#{schema.default_link_namespace}__#{directive[:name]}"
      else
        directive[:name]
      end
    end

    def build_arguments_node(arguments)
      (arguments || []).map do |arg|
        GraphQL::Language::Nodes::Argument.new(name: arg[:name], value: arg[:values])
      end
    end
  end
end
