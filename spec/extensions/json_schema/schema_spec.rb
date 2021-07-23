# frozen_string_literal: true

require "json-schema"

RSpec.describe Dry::Schema::JSON, "#json_schema" do
  before do
    Dry::Schema.load_extensions(:json_schema)
  end

  shared_examples "metaschema validation" do
    describe "validating against the metaschema" do
      it "produces a valid json schema document for draft6" do
        metaschema = JSON::Validator.validator_for_name("draft6").metaschema
        input = schema.respond_to?(:json_schema) ? schema.json_schema : schema

        JSON::Validator.validate!(metaschema, input)
      end
    end
  end

  context "when using a realistic schema with nested data" do
    subject(:schema) do
      Dry::Schema.JSON do
        required(:email).filled(:string)

        optional(:age).filled(:integer)

        required(:roles).array(:hash) do
          required(:name).filled(:string, min_size?: 12, max_size?: 36)
        end

        optional(:address).hash do
          optional(:street).filled(:string)
        end
      end
    end

    include_examples "metaschema validation"

    it "returns the correct json schema" do
      expect(schema.json_schema).to eql(
        "$schema": "http://json-schema.org/draft-06/schema#",
        type: "object",
        properties: {
          email: {
            type: "string"
          },
          age: {
            type: "integer"
          },
          roles: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: {
                  type: "string",
                  minLength: 12,
                  maxLength: 36
                }
              },
              required: ["name"]
            }
          },
          address: {
            type: "object",
            properties: {
              street: {
                type: "string"
              }
            },
            required: []
          }
        },
        required: %w[email roles]
      )
    end
  end

  context "when using maybe types" do
    include_examples "metaschema validation"

    subject(:schema) do
      Dry::Schema.JSON do
        required(:email).maybe(:string)
      end
    end

    it "returns the correct json schema" do
      expect(schema.json_schema).to eql(
        "$schema": "http://json-schema.org/draft-06/schema#",
        type: "object",
        properties: {
          email: {
            type: %w[null string]
          }
        },
        required: %w[email]
      )
    end
  end

  context "when using enums" do
    include_examples "metaschema validation"

    subject(:schema) do
      Dry::Schema.JSON do
        required(:color).filled(:str?, included_in?: %w[red blue])
        required(:shade).filled(Types::String.enum("light", "dark"))
      end
    end

    it "returns the correct json schema" do
      expect(schema.json_schema).to eql(
        "$schema": "http://json-schema.org/draft-06/schema#",
        type: "object",
        properties: {
          color: {
            type: "string",
            enum: %w[red blue]
          },
          shade: {
            type: "string",
            enum: %w[light dark]
          }
        },
        required: %w[color shade]
      )
    end
  end

  describe "inferring types" do
    {
      array: {type: "array"},
      bool: {type: "boolean"},
      date: {type: "string", format: "date"},
      date_time: {type: "string", format: "date-time"},
      decimal: {type: "number"},
      float: {type: "number"},
      hash: {type: "object"},
      integer: {type: "integer"},
      nil: {type: "null"},
      string: {type: "string"},
      time: {type: "string", format: "time"},
      uuid_v1?: {pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-1[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$"},
      uuid_v2?: {pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-2[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$"},
      uuid_v3?: {pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-3[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$"},
      uuid_v4?: {pattern: "^[a-f0-9]{8}-?[a-f0-9]{4}-?4[a-f0-9]{3}-?[89ab][a-f0-9]{3}-?[a-f0-9]{12}$"},
      uuid_v5?: {pattern: "^[0-9A-F]{8}-[0-9A-F]{4}-5[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$"}
    }.each do |type_spec, type_opts|
      describe "type: #{type_spec.inspect}" do
        subject(:schema) do
          Dry::Schema.define { required(:key).value(type_spec) }.json_schema
        end

        include_examples "metaschema validation"

        it "infers with correct default options - #{type_opts.to_json}" do
          expect(schema).to include(
            type: "object",
            properties: {key: type_opts},
            required: ["key"]
          )
        end
      end
    end
  end

  describe "special string predictes" do
    {
      {uri?: "https"} => {type: "string", format: "uri"}
    }.each do |type_spec, type_opts|
      describe "type: #{type_spec.inspect}" do
        subject(:schema) do
          Dry::Schema.define { required(:key).value(:string, **type_spec) }.json_schema
        end

        include_examples "metaschema validation"

        it "infers with correct default options - #{type_opts.to_json}" do
          expect(schema).to include(
            properties: {key: type_opts}
          )
        end
      end
    end
  end

  describe "special number predictes" do
    {
      {gt?: 5} => {type: "integer", exclusiveMinimum: 5},
      {gteq?: 5} => {type: "integer", mininum: 5},
      {lt?: 5} => {type: "integer", exclusiveMaximum: 5},
      {lteq?: 5} => {type: "integer", maximum: 5},
      odd?: {type: "integer", not: {multipleOf: 2}},
      even?: {type: "integer", multipleOf: 2}
    }.each do |type_spec, type_opts|
      describe "type: #{type_spec.inspect}" do
        subject(:schema) do
          if type_spec.is_a?(Hash)
            Dry::Schema.define { required(:key).value(:int?, **type_spec) }.json_schema
          else
            Dry::Schema.define { required(:key).value(type_spec) }.json_schema
          end
        end

        include_examples "metaschema validation"

        it "infers with correct default options - #{type_opts.to_json}" do
          expect(schema).to include(
            properties: {key: type_opts}
          )
        end
      end
    end
  end
end
