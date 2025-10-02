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

  context 'with list_size directive' do
    let(:test_resolver) do
      Class.new(GraphQL::Schema::Resolver) do
        include ApolloFederation::Resolver

        type [String], null: false
        list_size slicing_arguments: [:limit], assumed_size: 100
      end
    end

    let(:product) do
      resolver = test_resolver
      Class.new(base_object) do
        graphql_name 'Product'
        field :items, resolver: resolver
      end
    end

    let(:field) { product.fields['items'] }
    let(:directives) { field.federation_directives }

    it 'adds the directive' do
      expect(directives.length).to eq(1)
    end

    it 'sets the directive name to listSize' do
      expect(directives.first[:name]).to eq('listSize')
    end

    it 'sets slicing_arguments' do
      arguments = directives.first[:arguments]
      expect(arguments).to include(hash_including(name: 'slicingArguments', values: [:limit]))
    end

    it 'sets assumed_size' do
      arguments = directives.first[:arguments]
      expect(arguments).to include(hash_including(name: 'assumedSize', values: 100))
    end
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

  context 'with multiple list_size options' do
    let(:test_resolver) do
      Class.new(GraphQL::Schema::Resolver) do
        include ApolloFederation::Resolver

        type [String], null: false
        list_size slicing_arguments: %i[limit offset],
                  require_one_slicing_argument: false,
                  assumed_size: 50
      end
    end

    let(:product) do
      resolver = test_resolver
      Class.new(base_object) do
        graphql_name 'Product'
        field :items, resolver: resolver
      end
    end

    let(:field) { product.fields['items'] }
    let(:directives) { field.federation_directives }
    let(:arguments) { directives.first[:arguments] }

    it 'adds the directive' do
      expect(directives.length).to eq(1)
    end

    it 'sets multiple slicing_arguments' do
      expect(arguments).to include(hash_including(name: 'slicingArguments', values: %i[limit offset]))
    end

    it 'sets require_one_slicing_argument' do
      expect(arguments).to include(hash_including(name: 'requireOneSlicingArgument', values: false))
    end

    it 'sets assumed_size' do
      expect(arguments).to include(hash_including(name: 'assumedSize', values: 50))
    end
  end

  context 'when generating SDL' do
    let(:base_schema) do
      Class.new(GraphQL::Schema) do
        include ApolloFederation::Schema
      end
    end

    let(:test_resolver) do
      Class.new(GraphQL::Schema::Resolver) do
        include ApolloFederation::Resolver

        type [String], null: false
        list_size slicing_arguments: [:limit], assumed_size: 100
      end
    end

    let(:product) do
      resolver = test_resolver
      base = base_object
      Class.new(base) do
        graphql_name 'Product'
        key fields: :id

        field :id, 'ID', null: false
        field :items, resolver: resolver
      end
    end

    let(:schema) do
      prod = product
      base = base_schema
      Class.new(base) do
        orphan_types prod
        federation version: '2.9'
      end
    end

    let(:sdl) { schema.execute('{ _service { sdl } }')['data']['_service']['sdl'] }

    it 'includes @listSize directive' do
      expect(sdl).to include('@listSize')
    end

    it 'includes slicing_arguments in SDL' do
      expect(sdl).to include('slicingArguments: ["limit"]')
    end

    it 'includes assumed_size in SDL' do
      expect(sdl).to include('assumedSize: 100')
    end
  end
end
