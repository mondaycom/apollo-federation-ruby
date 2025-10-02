# frozen_string_literal: true

require 'spec_helper'
require 'graphql'
require 'apollo-federation/resolver'
require 'apollo-federation/field'
require 'apollo-federation/object'
require 'apollo-federation/schema'

RSpec.describe ApolloFederation::Resolver do
  let(:base_field) do
    Class.new(GraphQL::Schema::Field) do
      include ApolloFederation::Field

      def initialize(*args, **kwargs, &block)
        super(*args, **kwargs, &block)
        resolver_class = kwargs[:resolver_class]

        return unless resolver_class.respond_to?(:apply_list_size_directive)

        resolver_class.apply_list_size_directive(self)
      end
    end
  end

  let(:base_object) do
    field_class = base_field
    Class.new(GraphQL::Schema::Object) do
      include ApolloFederation::Object
      field_class field_class
    end
  end

  it 'adds list_size directive through resolver' do
    test_resolver = Class.new(GraphQL::Schema::Resolver) do
      include ApolloFederation::Resolver

      type [String], null: false
      list_size slicing_arguments: [:limit], assumed_size: 100
    end

    product = Class.new(base_object) do
      graphql_name 'Product'

      field :items, resolver: test_resolver
    end

    # Get the field to check the directives
    field = product.fields['items']
    directives = field.federation_directives

    expect(directives.length).to eq(1)
    expect(directives.first[:name]).to eq('listSize')

    arguments = directives.first[:arguments]
    expect(arguments).to include(hash_including(name: 'slicingArguments', values: [:limit]))
    expect(arguments).to include(hash_including(name: 'assumedSize', values: 100))
  end

  it 'works without list_size directive' do
    test_resolver = Class.new(GraphQL::Schema::Resolver) do
      include ApolloFederation::Resolver

      type [String], null: false
    end

    product = Class.new(base_object) do
      graphql_name 'Product'

      field :items, resolver: test_resolver
    end

    field = product.fields['items']
    directives = field.federation_directives

    expect(directives).to be_empty
  end

  it 'supports multiple list_size options' do
    test_resolver = Class.new(GraphQL::Schema::Resolver) do
      include ApolloFederation::Resolver

      type [String], null: false
      list_size slicing_arguments: [:limit, :offset],
                require_one_slicing_argument: false,
                assumed_size: 50
    end

    product = Class.new(base_object) do
      graphql_name 'Product'

      field :items, resolver: test_resolver
    end

    field = product.fields['items']
    directives = field.federation_directives

    expect(directives.length).to eq(1)
    expect(directives.first[:name]).to eq('listSize')

    arguments = directives.first[:arguments]
    expect(arguments).to include(hash_including(name: 'slicingArguments', values: [:limit, :offset]))
    expect(arguments).to include(hash_including(name: 'requireOneSlicingArgument', values: false))
    expect(arguments).to include(hash_including(name: 'assumedSize', values: 50))
  end

  it 'generates correct SDL with list_size directive' do
    base_schema = Class.new(GraphQL::Schema) do
      include ApolloFederation::Schema
    end

    test_resolver = Class.new(GraphQL::Schema::Resolver) do
      include ApolloFederation::Resolver

      type [String], null: false
      list_size slicing_arguments: [:limit], assumed_size: 100
    end

    product = Class.new(base_object) do
      graphql_name 'Product'
      key fields: :id

      field :id, 'ID', null: false
      field :items, resolver: test_resolver
    end

    schema = Class.new(base_schema) do
      orphan_types product
      federation version: '2.9'
    end

    sdl = schema.execute('{ _service { sdl } }')['data']['_service']['sdl']

    expect(sdl).to include('@listSize')
    expect(sdl).to include('slicingArguments: ["limit"]')
    expect(sdl).to include('assumedSize: 100')
  end
end
