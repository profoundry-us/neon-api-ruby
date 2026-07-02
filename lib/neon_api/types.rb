# frozen_string_literal: true

# =============================================================================
# GENERATED FILE — DO NOT EDIT BY HAND. Regenerate with:  rake types:generate
#
# Typed response wrappers for the Neon API, generated from the OpenAPI
# specification by lib/neon_api/type_generator.rb.
#
# Source:    https://neon.com/api_spec/release/v2.json
# Generated: 2026-07-02 (67 classes)
# =============================================================================

require_relative "object"

module NeonAPI
  # Typed views over API responses. Every class here is a {NeonAPI::Object},
  # so hash-style access, `to_h`, the `?` suffix, and dynamic method access
  # keep working — including for fields newer than this generated file.
  module Types
    # Wrap a raw JSON value: hashes become `type` instances, arrays are
    # mapped element-wise, everything else (including nil) passes through.
    def self.wrap(value, type)
      case value
      when ::Hash then type.new(value)
      when ::Array then value.map { |item| wrap(item, type) }
      else value
      end
    end

    # A list of IP addresses that are allowed to connect to the compute endpoint.
    class AllowedIps < NeonAPI::Object
      # A list of IP addresses that are allowed to connect to the endpoint.
      # @return [Array<String>, nil]
      def ips
        self["ips"]
      end

      # If true, the list will be applied only to protected branches.
      # @return [Boolean, nil]
      def protected_branches_only
        self["protected_branches_only"]
      end
    end


    # Generated from the OpenAPI schema `AnnotationData`.
    class AnnotationData < NeonAPI::Object
      # @return [AnnotationObjectData]
      def object
        Types.wrap(to_h["object"], AnnotationObjectData)
      end

      # Annotation properties.
      # @return [AnnotationValueData]
      def value
        Types.wrap(to_h["value"], AnnotationValueData)
      end

      # @return [String, nil]
      def created_at
        self["created_at"]
      end

      # @return [String, nil]
      def updated_at
        self["updated_at"]
      end
    end


    # Generated from the OpenAPI schema `AnnotationObjectData`.
    class AnnotationObjectData < NeonAPI::Object
      # @return [String]
      def type
        self["type"]
      end

      # @return [String]
      def id
        self["id"]
      end
    end


    # Annotation properties.
    class AnnotationValueData < NeonAPI::Object
    end


    # Generated from the OpenAPI schema `ApiKeyCreateResponse`.
    class ApiKeyCreateResponse < NeonAPI::Object
      # The API key ID
      # @return [Integer]
      def id
        self["id"]
      end

      # The generated 64-bit token required to access the Neon API
      # @return [String]
      def key
        self["key"]
      end

      # The user-specified API key name
      # @return [String]
      def name
        self["name"]
      end

      # A timestamp indicating when the API key was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # ID of the user who created this API key
      # @return [String]
      def created_by
        self["created_by"]
      end
    end


    # The user data of the user that created this API key.
    class ApiKeyCreatorData < NeonAPI::Object
      # ID of the user who created this API key
      # @return [String]
      def id
        self["id"]
      end

      # The name of the user.
      # @return [String]
      def name
        self["name"]
      end

      # The URL to the user's avatar image.
      # @return [String]
      def image
        self["image"]
      end
    end


    # Generated from the OpenAPI schema `ApiKeyRevokeResponse`.
    class ApiKeyRevokeResponse < NeonAPI::Object
      # The API key ID
      # @return [Integer]
      def id
        self["id"]
      end

      # The user-specified API key name
      # @return [String]
      def name
        self["name"]
      end

      # A timestamp indicating when the API key was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # ID of the user who created this API key
      # @return [String]
      def created_by
        self["created_by"]
      end

      # A timestamp indicating when the API was last used
      # @return [String, nil]
      def last_used_at
        self["last_used_at"]
      end

      # The IP address from which the API key was last used
      # @return [String]
      def last_used_from_addr
        self["last_used_from_addr"]
      end

      # A `true` or `false` value indicating whether the API key is revoked
      # @return [Boolean]
      def revoked
        self["revoked"]
      end
    end


    # Generated from the OpenAPI schema `ApiKeysListResponseItem`.
    class ApiKeysListResponseItem < NeonAPI::Object
      # The API key ID
      # @return [Integer]
      def id
        self["id"]
      end

      # The user-specified API key name
      # @return [String]
      def name
        self["name"]
      end

      # A timestamp indicating when the API key was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # The user data of the user that created this API key.
      # @return [ApiKeyCreatorData]
      def created_by
        Types.wrap(to_h["created_by"], ApiKeyCreatorData)
      end

      # A timestamp indicating when the API was last used
      # @return [String, nil]
      def last_used_at
        self["last_used_at"]
      end

      # The IP address from which the API key was last used
      # @return [String]
      def last_used_from_addr
        self["last_used_from_addr"]
      end
    end


    # Generated from the OpenAPI schema `BillingAccount`.
    class BillingAccount < NeonAPI::Object
      # State of the billing account.
      # One of: "UNKNOWN", "active", "suspended", "deactivated", "deleted".
      # @return [String]
      def state
        self["state"]
      end

      # @return [PaymentSource]
      def payment_source
        Types.wrap(to_h["payment_source"], PaymentSource)
      end

      # Type of subscription to Neon Cloud.
      # @return [String]
      def subscription_type
        self["subscription_type"]
      end

      # Indicates whether and how an account makes payments.
      # @return [String]
      def payment_method
        self["payment_method"]
      end

      # The last time the quota was reset. Defaults to the date-time the account is created.
      # @return [String]
      def quota_reset_at_last
        self["quota_reset_at_last"]
      end

      # The full name of the individual or entity that owns the billing account. This name appears ...
      # @return [String]
      def name
        self["name"]
      end

      # Billing email, to receive emails related to invoices and subscriptions.
      # @return [String]
      def email
        self["email"]
      end

      # Billing address city.
      # @return [String]
      def address_city
        self["address_city"]
      end

      # Billing address country code defined by ISO 3166-1 alpha-2.
      # @return [String]
      def address_country
        self["address_country"]
      end

      # Billing address country name.
      # @return [String, nil]
      def address_country_name
        self["address_country_name"]
      end

      # Billing address line 1.
      # @return [String]
      def address_line1
        self["address_line1"]
      end

      # Billing address line 2.
      # @return [String]
      def address_line2
        self["address_line2"]
      end

      # Billing address postal code.
      # @return [String]
      def address_postal_code
        self["address_postal_code"]
      end

      # Billing address state or region.
      # @return [String]
      def address_state
        self["address_state"]
      end

      # Orb user portal url
      # @return [String, nil]
      def orb_portal_url
        self["orb_portal_url"]
      end

      # The tax identification number for the billing account, displayed on invoices.
      # @return [String, nil]
      def tax_id
        self["tax_id"]
      end

      # The type of the tax identification number based on the country.
      # @return [String, nil]
      def tax_id_type
        self["tax_id_type"]
      end

      # @return [PlanDetails, nil]
      def plan_details
        Types.wrap(to_h["plan_details"], PlanDetails)
      end

      # Monthly spending cap in cents for V3 paid plans. When set,
      # @return [Integer, nil]
      def spending_limit_cents
        self["spending_limit_cents"]
      end
    end


    # Generated from the OpenAPI schema `Branch`.
    class Branch < NeonAPI::Object
      # The branch ID. This value is generated when a branch is created. A `branch_id` value has a ...
      # @return [String]
      def id
        self["id"]
      end

      # The ID of the project to which the branch belongs
      # @return [String]
      def project_id
        self["project_id"]
      end

      # The `branch_id` of the parent branch
      # @return [String, nil]
      def parent_id
        self["parent_id"]
      end

      # The Log Sequence Number (LSN) on the parent branch from which this branch was created.
      # @return [String, nil]
      def parent_lsn
        self["parent_lsn"]
      end

      # The point in time on the parent branch from which this branch was created.
      # @return [String, nil]
      def parent_timestamp
        self["parent_timestamp"]
      end

      # The branch name
      # @return [String]
      def name
        self["name"]
      end

      # The branch’s state, indicating if it is initializing, ready for use, or archived.
      # @return [String]
      def current_state
        self["current_state"]
      end

      # The branch’s state, indicating if it is initializing, ready for use, or archived.
      # @return [String, nil]
      def pending_state
        self["pending_state"]
      end

      # A UTC timestamp indicating when the `current_state` began
      # @return [String]
      def state_changed_at
        self["state_changed_at"]
      end

      # The logical size of the branch, in bytes
      # @return [Integer, nil]
      def logical_size
        self["logical_size"]
      end

      # The branch creation source
      # @return [String]
      def creation_source
        self["creation_source"]
      end

      # DEPRECATED. Use `default` field.
      # @return [Boolean, nil]
      def primary
        self["primary"]
      end

      # Whether the branch is the project's default branch
      # @return [Boolean]
      def default
        self["default"]
      end

      # Whether the branch is protected
      # @return [Boolean]
      def protected
        self["protected"]
      end

      # CPU seconds used by all of the branch's compute endpoints, including deleted ones.
      # @return [Integer]
      def cpu_used_sec
        self["cpu_used_sec"]
      end

      # @return [Integer]
      def compute_time_seconds
        self["compute_time_seconds"]
      end

      # @return [Integer]
      def active_time_seconds
        self["active_time_seconds"]
      end

      # @return [Integer]
      def written_data_bytes
        self["written_data_bytes"]
      end

      # @return [Integer]
      def data_transfer_bytes
        self["data_transfer_bytes"]
      end

      # A timestamp indicating when the branch was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the branch was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end

      # The time-to-live (TTL) duration originally configured for the branch, in seconds. This read...
      # @return [Integer, nil]
      def ttl_interval_seconds
        self["ttl_interval_seconds"]
      end

      # The timestamp when the branch is scheduled to expire and be automatically deleted. Must be ...
      # @return [String, nil]
      def expires_at
        self["expires_at"]
      end

      # A timestamp indicating when the branch was last reset
      # @return [String, nil]
      def last_reset_at
        self["last_reset_at"]
      end

      # The resolved user model that contains details of the user/org/integration/api_key used for ...
      # @return [NeonAPI::Object, nil]
      def created_by
        self["created_by"]
      end

      # The source of initialization for the branch. Valid values are `schema-only` and `parent-dat...
      # @return [String, nil]
      def init_source
        self["init_source"]
      end

      # Could be `restored`, `finalized` or `detaching`.
      # @return [String, nil]
      def restore_status
        self["restore_status"]
      end

      # ID of the snapshot that was the restore source for this branch
      # @return [String, nil]
      def restored_from
        self["restored_from"]
      end

      # ID of the target branch which was replaced when this branch was restored
      # @return [String, nil]
      def restored_as
        self["restored_as"]
      end

      # A list of actions that are currently restricted for this branch and the reason why.
      # @return [Array<BranchRestrictedAction>, nil]
      def restricted_actions
        Types.wrap(to_h["restricted_actions"], BranchRestrictedAction)
      end

      # Recovery information for a deleted branch. Only present when listing deleted branches
      # @return [BranchRecoveryInfo, nil]
      def recovery
        Types.wrap(to_h["recovery"], BranchRecoveryInfo)
      end
    end


    # BranchCreated — merged (allOf) response: BranchResponse + EndpointsResponse + OperationsResponse + RolesResponse + DatabasesResponse + ConnectionURIsOptionalResponse.
    class BranchCreated < NeonAPI::Object
      # @return [Branch]
      def branch
        Types.wrap(to_h["branch"], Branch)
      end

      # @return [Array<Endpoint>]
      def endpoints
        Types.wrap(to_h["endpoints"], Endpoint)
      end

      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end

      # @return [Array<Role>]
      def roles
        Types.wrap(to_h["roles"], Role)
      end

      # @return [Array<Database>]
      def databases
        Types.wrap(to_h["databases"], Database)
      end

      # @return [Array<ConnectionDetails>, nil]
      def connection_uris
        Types.wrap(to_h["connection_uris"], ConnectionDetails)
      end
    end


    # BranchDetail — merged (allOf) response: BranchResponse + AnnotationResponse.
    class BranchDetail < NeonAPI::Object
      # @return [Branch]
      def branch
        Types.wrap(to_h["branch"], Branch)
      end

      # @return [AnnotationData]
      def annotation
        Types.wrap(to_h["annotation"], AnnotationData)
      end
    end


    # Recovery information for a deleted branch. Only present when listing deleted branches
    class BranchRecoveryInfo < NeonAPI::Object
      # Timestamp when the branch was deleted
      # @return [String]
      def deleted_at
        self["deleted_at"]
      end

      # Timestamp when the recovery window expires and the branch will be permanently deleted
      # @return [String]
      def recoverable_until
        self["recoverable_until"]
      end

      # How the branch was deleted: 'user' for manual deletion, 'ttl' for TTL expiration
      # One of: "user", "ttl".
      # @return [String]
      def deletion_method
        self["deletion_method"]
      end
    end


    # An action that is currently restricted for the branch and the reason why.
    class BranchRestrictedAction < NeonAPI::Object
      # The name of a restricted action. Possible values include `restore`, `delete-rw-endpoint`.
      # @return [String]
      def name
        self["name"]
      end

      # A human-readable explanation of why the action is restricted.
      # @return [String]
      def reason
        self["reason"]
      end
    end


    # BranchesList — merged (allOf) response: BranchesResponse + AnnotationsMapResponse + CursorPaginationResponse.
    class BranchesList < NeonAPI::Object
      # @return [Array<Branch>]
      def branches
        Types.wrap(to_h["branches"], Branch)
      end

      # @return [NeonAPI::Object]
      def annotations
        self["annotations"]
      end

      # To paginate the response, issue an initial request with `limit` value. Then, add the value ...
      # @return [CursorPagination, nil]
      def pagination
        Types.wrap(to_h["pagination"], CursorPagination)
      end
    end


    # Generated from the OpenAPI schema `ConnectionDetails`.
    class ConnectionDetails < NeonAPI::Object
      # The connection URI is defined as specified here: [Connection URIs](https://www.postgresql.o...
      # @return [String]
      def connection_uri
        self["connection_uri"]
      end

      # @return [ConnectionParameters]
      def connection_parameters
        Types.wrap(to_h["connection_parameters"], ConnectionParameters)
      end
    end


    # Generated from the OpenAPI schema `ConnectionParameters`.
    class ConnectionParameters < NeonAPI::Object
      # Database name
      # @return [String]
      def database
        self["database"]
      end

      # Password for the role
      # @return [String]
      def password
        self["password"]
      end

      # Role name
      # @return [String]
      def role
        self["role"]
      end

      # Hostname
      # @return [String]
      def host
        self["host"]
      end

      # Pooler hostname
      # @return [String]
      def pooler_host
        self["pooler_host"]
      end
    end


    # Generated from the OpenAPI schema `ConnectionURIResponse`.
    class ConnectionURIResponse < NeonAPI::Object
      # The connection URI.
      # @return [String]
      def uri
        self["uri"]
      end
    end


    # Generated from the OpenAPI schema `ConsumptionHistoryPerPeriod`.
    class ConsumptionHistoryPerPeriod < NeonAPI::Object
      # The ID assigned to the specified billing period.
      # @return [String]
      def period_id
        self["period_id"]
      end

      # The billing plan applicable during the billing period.
      # @return [String]
      def period_plan
        self["period_plan"]
      end

      # The start date-time of the billing period.
      # @return [String]
      def period_start
        self["period_start"]
      end

      # The end date-time of the billing period, available for the past periods only.
      # @return [String, nil]
      def period_end
        self["period_end"]
      end

      # @return [Array<ConsumptionHistoryPerTimeframe>]
      def consumption
        Types.wrap(to_h["consumption"], ConsumptionHistoryPerTimeframe)
      end
    end


    # Generated from the OpenAPI schema `ConsumptionHistoryPerProject`.
    class ConsumptionHistoryPerProject < NeonAPI::Object
      # The project ID
      # @return [String]
      def project_id
        self["project_id"]
      end

      # @return [Array<ConsumptionHistoryPerPeriod>]
      def periods
        Types.wrap(to_h["periods"], ConsumptionHistoryPerPeriod)
      end
    end


    # Generated from the OpenAPI schema `ConsumptionHistoryPerTimeframe`.
    class ConsumptionHistoryPerTimeframe < NeonAPI::Object
      # The specified start date-time for the reported consumption.
      # @return [String]
      def timeframe_start
        self["timeframe_start"]
      end

      # The specified end date-time for the reported consumption.
      # @return [String]
      def timeframe_end
        self["timeframe_end"]
      end

      # Seconds. The amount of time the compute endpoints have been active.
      # @return [Integer]
      def active_time_seconds
        self["active_time_seconds"]
      end

      # Seconds. The number of CPU seconds used by compute endpoints, including compute endpoints t...
      # @return [Integer]
      def compute_time_seconds
        self["compute_time_seconds"]
      end

      # Bytes. The amount of written data for all branches.
      # @return [Integer]
      def written_data_bytes
        self["written_data_bytes"]
      end

      # Bytes. The space occupied in storage. Synthetic storage size combines the logical data size...
      # @return [Integer]
      def synthetic_storage_size_bytes
        self["synthetic_storage_size_bytes"]
      end

      # Bytes-Hour. The amount of storage consumed hourly.
      # @return [Integer, nil]
      def data_storage_bytes_hour
        self["data_storage_bytes_hour"]
      end

      # Bytes. The amount of logical size consumed.
      # @return [Integer, nil]
      def logical_size_bytes
        self["logical_size_bytes"]
      end

      # Bytes-Hour. The amount of logical size consumed hourly.
      # @return [Integer, nil]
      def logical_size_bytes_hour
        self["logical_size_bytes_hour"]
      end
    end


    # ConsumptionHistoryProjectsList — merged (allOf) response: ConsumptionHistoryPerProjectResponse + PaginationResponse.
    class ConsumptionHistoryProjectsList < NeonAPI::Object
      # @return [Array<ConsumptionHistoryPerProject>]
      def projects
        Types.wrap(to_h["projects"], ConsumptionHistoryPerProject)
      end

      # Cursor based pagination is used. The user must pass the cursor as is to the backend.
      # @return [Pagination, nil]
      def pagination
        Types.wrap(to_h["pagination"], Pagination)
      end
    end


    # Generated from the OpenAPI schema `CurrentUserAuthAccount`.
    class CurrentUserAuthAccount < NeonAPI::Object
      # @return [String]
      def email
        self["email"]
      end

      # @return [String]
      def image
        self["image"]
      end

      # DEPRECATED. Use `email` field.
      # @return [String]
      def login
        self["login"]
      end

      # @return [String]
      def name
        self["name"]
      end

      # Identity provider id from keycloak
      # One of: "github", "google", "hasura", "microsoft", "microsoftv2", "vercelmp", "keycloak".
      # @return [String]
      def provider
        self["provider"]
      end
    end


    # Generated from the OpenAPI schema `CurrentUserInfoResponse`.
    class CurrentUserInfoResponse < NeonAPI::Object
      # Control plane observes active endpoints of a user this amount of wall-clock time.
      # @return [Integer]
      def active_seconds_limit
        self["active_seconds_limit"]
      end

      # @return [BillingAccount, nil]
      def billing_account
        Types.wrap(to_h["billing_account"], BillingAccount)
      end

      # @return [Array<CurrentUserAuthAccount>]
      def auth_accounts
        Types.wrap(to_h["auth_accounts"], CurrentUserAuthAccount)
      end

      # @return [String]
      def email
        self["email"]
      end

      # @return [String]
      def id
        self["id"]
      end

      # @return [String]
      def image
        self["image"]
      end

      # DEPRECATED. Use `email` field.
      # @return [String]
      def login
        self["login"]
      end

      # @return [String]
      def name
        self["name"]
      end

      # @return [String]
      def last_name
        self["last_name"]
      end

      # @return [Integer]
      def projects_limit
        self["projects_limit"]
      end

      # @return [Integer]
      def branches_limit
        self["branches_limit"]
      end

      # The maximum autoscaling limit in Compute Units.
      # @return [Float]
      def max_autoscaling_limit
        self["max_autoscaling_limit"]
      end

      # @return [Integer, nil]
      def compute_seconds_limit
        self["compute_seconds_limit"]
      end

      # @return [String]
      def plan
        self["plan"]
      end
    end


    # To paginate the response, issue an initial request with `limit` value. Then, add the value ...
    class CursorPagination < NeonAPI::Object
      # NOTE: `next` is not a valid method name; read it with obj["next"].

      # @return [String, nil]
      def sort_by
        self["sort_by"]
      end

      # @return [String, nil]
      def sort_order
        self["sort_order"]
      end
    end


    # Generated from the OpenAPI schema `Database`.
    class Database < NeonAPI::Object
      # The database ID
      # @return [Integer]
      def id
        self["id"]
      end

      # The ID of the branch to which the database belongs
      # @return [String]
      def branch_id
        self["branch_id"]
      end

      # The database name
      # @return [String]
      def name
        self["name"]
      end

      # The name of role that owns the database
      # @return [String]
      def owner_name
        self["owner_name"]
      end

      # A timestamp indicating when the database was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the database was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end
    end


    # Generated from the OpenAPI schema `DatabaseOperations`.
    class DatabaseOperations < NeonAPI::Object
      # @return [Database]
      def database
        Types.wrap(to_h["database"], Database)
      end

      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end
    end


    # Generated from the OpenAPI schema `DatabaseResponse`.
    class DatabaseResponse < NeonAPI::Object
      # @return [Database]
      def database
        Types.wrap(to_h["database"], Database)
      end
    end


    # Generated from the OpenAPI schema `DatabasesResponse`.
    class DatabasesResponse < NeonAPI::Object
      # @return [Array<Database>]
      def databases
        Types.wrap(to_h["databases"], Database)
      end
    end


    # A collection of settings for a Neon endpoint
    class DefaultEndpointSettings < NeonAPI::Object
      # A raw representation of Postgres settings
      # @return [PgSettingsData, nil]
      def pg_settings
        Types.wrap(to_h["pg_settings"], PgSettingsData)
      end

      # DEPRECATED. PgBouncer settings for the compute endpoint. This field is deprecated and will ...
      # @return [PgbouncerSettingsData, nil]
      def pgbouncer_settings
        Types.wrap(to_h["pgbouncer_settings"], PgbouncerSettingsData)
      end

      # The minimum number of Compute Units. The minimum value is `0.25`.
      # @return [Float, nil]
      def autoscaling_limit_min_cu
        self["autoscaling_limit_min_cu"]
      end

      # The maximum number of Compute Units. See [Compute size and Autoscaling configuration](https...
      # @return [Float, nil]
      def autoscaling_limit_max_cu
        self["autoscaling_limit_max_cu"]
      end

      # Duration of inactivity in seconds after which the compute endpoint is
      # @return [Integer, nil]
      def suspend_timeout_seconds
        self["suspend_timeout_seconds"]
      end
    end


    # Generated from the OpenAPI schema `Endpoint`.
    class Endpoint < NeonAPI::Object
      # The hostname of the compute endpoint. This is the hostname specified when connecting to a N...
      # @return [String]
      def host
        self["host"]
      end

      # The compute endpoint ID. Compute endpoint IDs have an `ep-` prefix. For example: `ep-little...
      # @return [String]
      def id
        self["id"]
      end

      # Optional name of the compute endpoint
      # @return [String, nil]
      def name
        self["name"]
      end

      # The ID of the project to which the compute endpoint belongs
      # @return [String]
      def project_id
        self["project_id"]
      end

      # The ID of the branch that the compute endpoint is associated with
      # @return [String]
      def branch_id
        self["branch_id"]
      end

      # The minimum number of Compute Units
      # @return [Float]
      def autoscaling_limit_min_cu
        self["autoscaling_limit_min_cu"]
      end

      # The maximum number of Compute Units
      # @return [Float]
      def autoscaling_limit_max_cu
        self["autoscaling_limit_max_cu"]
      end

      # The region identifier
      # @return [String]
      def region_id
        self["region_id"]
      end

      # The compute endpoint type. Either `read_write` or `read_only`.
      # One of: "read_only", "read_write".
      # @return [String]
      def type
        self["type"]
      end

      # The state of the compute endpoint
      # One of: "init", "active", "idle".
      # @return [String]
      def current_state
        self["current_state"]
      end

      # The state of the compute endpoint
      # One of: "init", "active", "idle".
      # @return [String, nil]
      def pending_state
        self["pending_state"]
      end

      # A collection of settings for a compute endpoint
      # @return [EndpointSettingsData]
      def settings
        Types.wrap(to_h["settings"], EndpointSettingsData)
      end

      # DEPRECATED. Whether to enable connection pooling for the compute endpoint.
      # @return [Boolean]
      def pooler_enabled
        self["pooler_enabled"]
      end

      # DEPRECATED. The connection pooler mode. This field is deprecated and will be removed after ...
      # One of: "transaction".
      # @return [String]
      def pooler_mode
        self["pooler_mode"]
      end

      # Whether to restrict connections to the compute endpoint.
      # @return [Boolean]
      def disabled
        self["disabled"]
      end

      # Whether to permit passwordless access to the compute endpoint
      # @return [Boolean]
      def passwordless_access
        self["passwordless_access"]
      end

      # A timestamp indicating when the compute endpoint was last active
      # @return [String, nil]
      def last_active
        self["last_active"]
      end

      # The compute endpoint creation source
      # @return [String]
      def creation_source
        self["creation_source"]
      end

      # A timestamp indicating when the compute endpoint was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the compute endpoint was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end

      # A timestamp indicating when the compute endpoint was last started
      # @return [String, nil]
      def started_at
        self["started_at"]
      end

      # A timestamp indicating when the compute endpoint was last suspended
      # @return [String, nil]
      def suspended_at
        self["suspended_at"]
      end

      # DEPRECATED. Use the "host" property instead.
      # @return [String]
      def proxy_host
        self["proxy_host"]
      end

      # Duration of inactivity in seconds after which the compute endpoint is
      # @return [Integer]
      def suspend_timeout_seconds
        self["suspend_timeout_seconds"]
      end

      # The Neon compute provisioner.
      # @return [String]
      def provisioner
        self["provisioner"]
      end

      # Attached compute's release version number.
      # @return [String, nil]
      def compute_release_version
        self["compute_release_version"]
      end
    end


    # Generated from the OpenAPI schema `EndpointOperations`.
    class EndpointOperations < NeonAPI::Object
      # @return [Endpoint]
      def endpoint
        Types.wrap(to_h["endpoint"], Endpoint)
      end

      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end
    end


    # Generated from the OpenAPI schema `EndpointResponse`.
    class EndpointResponse < NeonAPI::Object
      # @return [Endpoint]
      def endpoint
        Types.wrap(to_h["endpoint"], Endpoint)
      end
    end


    # A collection of settings for a compute endpoint
    class EndpointSettingsData < NeonAPI::Object
      # A raw representation of Postgres settings
      # @return [PgSettingsData, nil]
      def pg_settings
        Types.wrap(to_h["pg_settings"], PgSettingsData)
      end

      # DEPRECATED. PgBouncer settings for the compute endpoint. This field is deprecated and will ...
      # @return [PgbouncerSettingsData, nil]
      def pgbouncer_settings
        Types.wrap(to_h["pgbouncer_settings"], PgbouncerSettingsData)
      end

      # The shared libraries to preload into the project's compute instances.
      # @return [PreloadLibraries, nil]
      def preload_libraries
        Types.wrap(to_h["preload_libraries"], PreloadLibraries)
      end
    end


    # Generated from the OpenAPI schema `EndpointsResponse`.
    class EndpointsResponse < NeonAPI::Object
      # @return [Array<Endpoint>]
      def endpoints
        Types.wrap(to_h["endpoints"], Endpoint)
      end
    end


    # Generated from the OpenAPI schema `ListNeonAuthOauthProvidersResponse`.
    class ListNeonAuthOauthProvidersResponse < NeonAPI::Object
      # @return [Array<NeonAuthOauthProvider>]
      def providers
        Types.wrap(to_h["providers"], NeonAuthOauthProvider)
      end
    end


    # A maintenance window is a time period during which Neon may perform maintenance on the proj...
    class MaintenanceWindow < NeonAPI::Object
      # A list of weekdays when the maintenance window is active.
      # @return [Array<Integer>]
      def weekdays
        self["weekdays"]
      end

      # Start time of the maintenance window, in the format of "HH:MM". Uses UTC.
      # @return [String]
      def start_time
        self["start_time"]
      end

      # End time of the maintenance window, in the format of "HH:MM". Uses UTC.
      # @return [String]
      def end_time
        self["end_time"]
      end
    end


    # Generated from the OpenAPI schema `NeonAuthConfigResponse`.
    class NeonAuthConfigResponse < NeonAPI::Object
      # The application name used in auth emails and communications.
      # @return [String]
      def name
        self["name"]
      end
    end


    # Generated from the OpenAPI schema `NeonAuthCreateIntegrationResponse`.
    class NeonAuthCreateIntegrationResponse < NeonAPI::Object
      # One of: "mock", "stack", "better_auth".
      # @return [String]
      def auth_provider
        self["auth_provider"]
      end

      # @return [String]
      def auth_provider_project_id
        self["auth_provider_project_id"]
      end

      # @return [String]
      def pub_client_key
        self["pub_client_key"]
      end

      # @return [String]
      def secret_server_key
        self["secret_server_key"]
      end

      # @return [String]
      def jwks_url
        self["jwks_url"]
      end

      # @return [String]
      def schema_name
        self["schema_name"]
      end

      # @return [String]
      def table_name
        self["table_name"]
      end

      # @return [String, nil]
      def base_url
        self["base_url"]
      end
    end


    # Generated from the OpenAPI schema `NeonAuthCreateNewUserResponse`.
    class NeonAuthCreateNewUserResponse < NeonAPI::Object
      # ID of newly created user
      # @return [String]
      def id
        self["id"]
      end
    end


    # Generated from the OpenAPI schema `NeonAuthIntegration`.
    class NeonAuthIntegration < NeonAPI::Object
      # One of: "mock", "stack", "better_auth".
      # @return [String]
      def auth_provider
        self["auth_provider"]
      end

      # @return [String]
      def auth_provider_project_id
        self["auth_provider_project_id"]
      end

      # @return [String]
      def branch_id
        self["branch_id"]
      end

      # @return [String]
      def db_name
        self["db_name"]
      end

      # @return [String]
      def created_at
        self["created_at"]
      end

      # One of: "user", "neon".
      # @return [String]
      def owned_by
        self["owned_by"]
      end

      # One of: "initiated", "finished".
      # @return [String, nil]
      def transfer_status
        self["transfer_status"]
      end

      # @return [String]
      def jwks_url
        self["jwks_url"]
      end

      # @return [String, nil]
      def base_url
        self["base_url"]
      end

      # The application name used in auth emails and communications. Defaults to the Neon project n...
      # @return [String, nil]
      def name
        self["name"]
      end
    end


    # Generated from the OpenAPI schema `NeonAuthOauthProvider`.
    class NeonAuthOauthProvider < NeonAPI::Object
      # One of: "google", "github", "microsoft", "vercel".
      # @return [String]
      def id
        self["id"]
      end

      # One of: "standard", "shared".
      # @return [String]
      def type
        self["type"]
      end

      # @return [String, nil]
      def client_id
        self["client_id"]
      end

      # @return [String, nil]
      def client_secret
        self["client_secret"]
      end
    end


    # Generated from the OpenAPI schema `Operation`.
    class Operation < NeonAPI::Object
      # The operation ID
      # @return [String]
      def id
        self["id"]
      end

      # The Neon project ID
      # @return [String]
      def project_id
        self["project_id"]
      end

      # The branch ID
      # @return [String, nil]
      def branch_id
        self["branch_id"]
      end

      # The endpoint ID
      # @return [String, nil]
      def endpoint_id
        self["endpoint_id"]
      end

      # The action performed by the operation
      # @return [String]
      def action
        self["action"]
      end

      # The status of the operation
      # One of: "scheduling", "running", "finished", "failed", "error", "cancelling", "cancelled", "skipped".
      # @return [String]
      def status
        self["status"]
      end

      # The error that occurred
      # @return [String, nil]
      def error
        self["error"]
      end

      # The number of times the operation failed
      # @return [Integer]
      def failures_count
        self["failures_count"]
      end

      # A timestamp indicating when the operation was last retried
      # @return [String, nil]
      def retry_at
        self["retry_at"]
      end

      # A timestamp indicating when the operation was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the operation status was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end

      # The total duration of the operation in milliseconds
      # @return [Integer]
      def total_duration_ms
        self["total_duration_ms"]
      end
    end


    # Generated from the OpenAPI schema `OperationResponse`.
    class OperationResponse < NeonAPI::Object
      # @return [Operation]
      def operation
        Types.wrap(to_h["operation"], Operation)
      end
    end


    # OperationsList — merged (allOf) response: OperationsResponse + PaginationResponse.
    class OperationsList < NeonAPI::Object
      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end

      # Cursor based pagination is used. The user must pass the cursor as is to the backend.
      # @return [Pagination, nil]
      def pagination
        Types.wrap(to_h["pagination"], Pagination)
      end
    end


    # Cursor based pagination is used. The user must pass the cursor as is to the backend.
    class Pagination < NeonAPI::Object
      # @return [String]
      def cursor
        self["cursor"]
      end
    end


    # Generated from the OpenAPI schema `PaymentSource`.
    class PaymentSource < NeonAPI::Object
      # Type of payment source. E.g. "card".
      # @return [String]
      def type
        self["type"]
      end

      # @return [PaymentSourceBankCard, nil]
      def card
        Types.wrap(to_h["card"], PaymentSourceBankCard)
      end
    end


    # Generated from the OpenAPI schema `PaymentSourceBankCard`.
    class PaymentSourceBankCard < NeonAPI::Object
      # Last 4 digits of the card.
      # @return [String]
      def last4
        self["last4"]
      end

      # Brand of credit card.
      # One of: "amex", "diners", "discover", "jcb", "mastercard", "unionpay", "unknown", "visa".
      # @return [String, nil]
      def brand
        self["brand"]
      end

      # Credit card expiration month
      # @return [Integer, nil]
      def exp_month
        self["exp_month"]
      end

      # Credit card expiration year
      # @return [Integer, nil]
      def exp_year
        self["exp_year"]
      end
    end


    # A raw representation of Postgres settings
    class PgSettingsData < NeonAPI::Object
    end


    # DEPRECATED. A raw representation of PgBouncer settings. This schema is deprecated and will ...
    class PgbouncerSettingsData < NeonAPI::Object
    end


    # Generated from the OpenAPI schema `PlanDetails`.
    class PlanDetails < NeonAPI::Object
      # @return [String]
      def name
        self["name"]
      end

      # @return [PlanVersion, nil]
      def version
        Types.wrap(to_h["version"], PlanVersion)
      end
    end


    # Generated from the OpenAPI schema `PlanVersion`.
    class PlanVersion < NeonAPI::Object
      # @return [Integer]
      def major
        self["major"]
      end

      # @return [Integer]
      def minor
        self["minor"]
      end
    end


    # The shared libraries to preload into the project's compute instances.
    class PreloadLibraries < NeonAPI::Object
      # @return [Boolean, nil]
      def use_defaults
        self["use_defaults"]
      end

      # @return [Array<String>, nil]
      def enabled_libraries
        self["enabled_libraries"]
      end
    end


    # Generated from the OpenAPI schema `Project`.
    class Project < NeonAPI::Object
      # Bytes-Hour. Project consumed that much storage hourly during the billing period. The value ...
      # @return [Integer]
      def data_storage_bytes_hour
        self["data_storage_bytes_hour"]
      end

      # Bytes. Egress traffic from the Neon cloud to the client for given project over the billing ...
      # @return [Integer]
      def data_transfer_bytes
        self["data_transfer_bytes"]
      end

      # Bytes. Amount of WAL that travelled through storage for given project across all branches.
      # @return [Integer]
      def written_data_bytes
        self["written_data_bytes"]
      end

      # Seconds. The number of CPU seconds used by the project's compute endpoints, including compu...
      # @return [Integer]
      def compute_time_seconds
        self["compute_time_seconds"]
      end

      # Seconds. Control plane observed endpoints of this project being active this amount of wall-...
      # @return [Integer]
      def active_time_seconds
        self["active_time_seconds"]
      end

      # DEPRECATED, use compute_time instead.
      # @return [Integer]
      def cpu_used_sec
        self["cpu_used_sec"]
      end

      # The project ID
      # @return [String]
      def id
        self["id"]
      end

      # The cloud platform identifier. Currently, only AWS is supported, for which the identifier i...
      # @return [String]
      def platform_id
        self["platform_id"]
      end

      # The region identifier
      # @return [String]
      def region_id
        self["region_id"]
      end

      # The project name
      # @return [String]
      def name
        self["name"]
      end

      # The Neon compute provisioner.
      # @return [String]
      def provisioner
        self["provisioner"]
      end

      # A collection of settings for a Neon endpoint
      # @return [DefaultEndpointSettings, nil]
      def default_endpoint_settings
        Types.wrap(to_h["default_endpoint_settings"], DefaultEndpointSettings)
      end

      # @return [ProjectSettingsData, nil]
      def settings
        Types.wrap(to_h["settings"], ProjectSettingsData)
      end

      # The major Postgres version number. Currently supported versions are `14`, `15`, `16`, `17`,...
      # @return [Integer]
      def pg_version
        self["pg_version"]
      end

      # The proxy host for the project. This value combines the `region_id`, the `platform_id`, and...
      # @return [String]
      def proxy_host
        self["proxy_host"]
      end

      # The logical size limit for a branch. The value is in MiB.
      # @return [Integer]
      def branch_logical_size_limit
        self["branch_logical_size_limit"]
      end

      # The logical size limit for a branch. The value is in B.
      # @return [Integer]
      def branch_logical_size_limit_bytes
        self["branch_logical_size_limit_bytes"]
      end

      # Whether or not passwords are stored for roles in the Neon project. Storing passwords facili...
      # @return [Boolean]
      def store_passwords
        self["store_passwords"]
      end

      # A timestamp indicating when project maintenance begins. If set, the project is placed into ...
      # @return [String, nil]
      def maintenance_starts_at
        self["maintenance_starts_at"]
      end

      # The project creation source
      # @return [String]
      def creation_source
        self["creation_source"]
      end

      # The number of seconds to retain the shared history for all branches in this project.
      # @return [Integer]
      def history_retention_seconds
        self["history_retention_seconds"]
      end

      # A timestamp indicating when the project was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the project was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end

      # The current space occupied by the project in storage, in bytes. Synthetic storage size comb...
      # @return [Integer, nil]
      def synthetic_storage_size
        self["synthetic_storage_size"]
      end

      # A date-time indicating when Neon Cloud started measuring consumption for current consumptio...
      # @return [String]
      def consumption_period_start
        self["consumption_period_start"]
      end

      # A date-time indicating when Neon Cloud plans to stop measuring consumption for current cons...
      # @return [String]
      def consumption_period_end
        self["consumption_period_end"]
      end

      # DEPRECATED. Use `consumption_period_end` from the getProject endpoint instead.
      # @return [String, nil]
      def quota_reset_at
        self["quota_reset_at"]
      end

      # @return [String]
      def owner_id
        self["owner_id"]
      end

      # @return [ProjectOwnerData, nil]
      def owner
        Types.wrap(to_h["owner"], ProjectOwnerData)
      end

      # The most recent time when any endpoint of this project was active.
      # @return [String, nil]
      def compute_last_active_at
        self["compute_last_active_at"]
      end

      # @return [String, nil]
      def org_id
        self["org_id"]
      end

      # A timestamp indicating when project update begins. If set, computes might experience a brie...
      # @return [String, nil]
      def maintenance_scheduled_for
        self["maintenance_scheduled_for"]
      end

      # A timestamp indicating when HIPAA was enabled for this project
      # @return [String, nil]
      def hipaa_enabled_at
        self["hipaa_enabled_at"]
      end

      # The caller's effective permission for a project when
      # One of: "CAN_VIEW", "CAN_EDIT", "CAN_MANAGE".
      # @return [String, nil]
      def effective_project_permission
        self["effective_project_permission"]
      end
    end


    # ProjectCreated — merged (allOf) response: ProjectResponse + ConnectionURIsResponse + RolesResponse + DatabasesResponse + OperationsResponse + BranchResponse + EndpointsResponse.
    class ProjectCreated < NeonAPI::Object
      # @return [Project]
      def project
        Types.wrap(to_h["project"], Project)
      end

      # @return [Array<ConnectionDetails>]
      def connection_uris
        Types.wrap(to_h["connection_uris"], ConnectionDetails)
      end

      # @return [Array<Role>]
      def roles
        Types.wrap(to_h["roles"], Role)
      end

      # @return [Array<Database>]
      def databases
        Types.wrap(to_h["databases"], Database)
      end

      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end

      # @return [Branch]
      def branch
        Types.wrap(to_h["branch"], Branch)
      end

      # @return [Array<Endpoint>]
      def endpoints
        Types.wrap(to_h["endpoints"], Endpoint)
      end
    end


    # Essential data about the project. Full data is available at the getProject endpoint.
    class ProjectListItem < NeonAPI::Object
      # The project ID
      # @return [String]
      def id
        self["id"]
      end

      # The cloud platform identifier. Currently, only AWS is supported, for which the identifier i...
      # @return [String]
      def platform_id
        self["platform_id"]
      end

      # The region identifier
      # @return [String]
      def region_id
        self["region_id"]
      end

      # The project name
      # @return [String]
      def name
        self["name"]
      end

      # The Neon compute provisioner.
      # @return [String]
      def provisioner
        self["provisioner"]
      end

      # A collection of settings for a Neon endpoint
      # @return [DefaultEndpointSettings, nil]
      def default_endpoint_settings
        Types.wrap(to_h["default_endpoint_settings"], DefaultEndpointSettings)
      end

      # @return [ProjectSettingsData, nil]
      def settings
        Types.wrap(to_h["settings"], ProjectSettingsData)
      end

      # The major Postgres version number. Currently supported versions are `14`, `15`, `16`, `17`,...
      # @return [Integer]
      def pg_version
        self["pg_version"]
      end

      # The proxy host for the project. This value combines the `region_id`, the `platform_id`, and...
      # @return [String]
      def proxy_host
        self["proxy_host"]
      end

      # The logical size limit for a branch. The value is in MiB.
      # @return [Integer]
      def branch_logical_size_limit
        self["branch_logical_size_limit"]
      end

      # The logical size limit for a branch. The value is in B.
      # @return [Integer]
      def branch_logical_size_limit_bytes
        self["branch_logical_size_limit_bytes"]
      end

      # Whether or not passwords are stored for roles in the Neon project. Storing passwords facili...
      # @return [Boolean]
      def store_passwords
        self["store_passwords"]
      end

      # Control plane observed endpoints of this project being active this amount of wall-clock time.
      # @return [Integer]
      def active_time
        self["active_time"]
      end

      # DEPRECATED. Use data from the getProject endpoint instead.
      # @return [Integer]
      def cpu_used_sec
        self["cpu_used_sec"]
      end

      # A timestamp indicating when project maintenance begins. If set, the project is placed into ...
      # @return [String, nil]
      def maintenance_starts_at
        self["maintenance_starts_at"]
      end

      # The project creation source
      # @return [String]
      def creation_source
        self["creation_source"]
      end

      # A timestamp indicating when the project was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the project was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end

      # The current space occupied by the project in storage, in bytes. Synthetic storage size comb...
      # @return [Integer, nil]
      def synthetic_storage_size
        self["synthetic_storage_size"]
      end

      # DEPRECATED. Use `consumption_period_end` from the getProject endpoint instead.
      # @return [String, nil]
      def quota_reset_at
        self["quota_reset_at"]
      end

      # @return [String]
      def owner_id
        self["owner_id"]
      end

      # The most recent time when any endpoint of this project was active.
      # @return [String, nil]
      def compute_last_active_at
        self["compute_last_active_at"]
      end

      # Organization id if the project belongs to an organization.
      # @return [String, nil]
      def org_id
        self["org_id"]
      end

      # Organization name if the project belongs to an organization.
      # @return [String, nil]
      def org_name
        self["org_name"]
      end

      # The number of seconds to retain the shared history for all branches in this project.
      # @return [Integer, nil]
      def history_retention_seconds
        self["history_retention_seconds"]
      end

      # A timestamp indicating when HIPAA was enabled for this project
      # @return [String, nil]
      def hipaa_enabled_at
        self["hipaa_enabled_at"]
      end

      # A timestamp indicating when the project was deleted
      # @return [String, nil]
      def deleted_at
        self["deleted_at"]
      end

      # A timestamp indicating the project will be recoverable until this date and time.
      # @return [String, nil]
      def recoverable_until
        self["recoverable_until"]
      end

      # The caller's effective permission for a project when
      # One of: "CAN_VIEW", "CAN_EDIT", "CAN_MANAGE".
      # @return [String, nil]
      def effective_project_permission
        self["effective_project_permission"]
      end
    end


    # ProjectOperations — merged (allOf) response: ProjectResponse + OperationsResponse.
    class ProjectOperations < NeonAPI::Object
      # @return [Project]
      def project
        Types.wrap(to_h["project"], Project)
      end

      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end
    end


    # Generated from the OpenAPI schema `ProjectOwnerData`.
    class ProjectOwnerData < NeonAPI::Object
      # @return [String]
      def email
        self["email"]
      end

      # @return [String]
      def name
        self["name"]
      end

      # @return [Integer]
      def branches_limit
        self["branches_limit"]
      end

      # Type of subscription to Neon Cloud.
      # @return [String]
      def subscription_type
        self["subscription_type"]
      end
    end


    # Per-project consumption quotas. If a quota is exceeded, all active computes
    class ProjectQuota < NeonAPI::Object
      # The total amount of wall-clock time allowed to be spent by the project's compute endpoints.
      # @return [Integer, nil]
      def active_time_seconds
        self["active_time_seconds"]
      end

      # The total amount of CPU seconds allowed to be spent by the project's compute endpoints.
      # @return [Integer, nil]
      def compute_time_seconds
        self["compute_time_seconds"]
      end

      # Total amount of data written to all of a project's branches.
      # @return [Integer, nil]
      def written_data_bytes
        self["written_data_bytes"]
      end

      # Total amount of data transferred from all of a project's branches using the proxy.
      # @return [Integer, nil]
      def data_transfer_bytes
        self["data_transfer_bytes"]
      end

      # Limit on the logical size of every project's branch.
      # @return [Integer, nil]
      def logical_size_bytes
        self["logical_size_bytes"]
      end
    end


    # Generated from the OpenAPI schema `ProjectResponse`.
    class ProjectResponse < NeonAPI::Object
      # @return [Project]
      def project
        Types.wrap(to_h["project"], Project)
      end
    end


    # Generated from the OpenAPI schema `ProjectSettingsData`.
    class ProjectSettingsData < NeonAPI::Object
      # Per-project consumption quotas. If a quota is exceeded, all active computes
      # @return [ProjectQuota, nil]
      def quota
        Types.wrap(to_h["quota"], ProjectQuota)
      end

      # A list of IP addresses that are allowed to connect to the compute endpoint.
      # @return [AllowedIps, nil]
      def allowed_ips
        Types.wrap(to_h["allowed_ips"], AllowedIps)
      end

      # Sets wal_level=logical for all compute endpoints in this project.
      # @return [Boolean, nil]
      def enable_logical_replication
        self["enable_logical_replication"]
      end

      # A maintenance window is a time period during which Neon may perform maintenance on the proj...
      # @return [MaintenanceWindow, nil]
      def maintenance_window
        Types.wrap(to_h["maintenance_window"], MaintenanceWindow)
      end

      # When set, connections from the public internet
      # @return [Boolean, nil]
      def block_public_connections
        self["block_public_connections"]
      end

      # When set, connections using VPC endpoints are disallowed.
      # @return [Boolean, nil]
      def block_vpc_connections
        self["block_vpc_connections"]
      end

      # One of: "base", "extended", "full".
      # @return [String, nil]
      def audit_log_level
        self["audit_log_level"]
      end

      # @return [Boolean, nil]
      def hipaa
        self["hipaa"]
      end

      # The shared libraries to preload into the project's compute instances.
      # @return [PreloadLibraries, nil]
      def preload_libraries
        Types.wrap(to_h["preload_libraries"], PreloadLibraries)
      end
    end


    # ProjectsList — merged (allOf) response: ProjectsResponse + PaginationResponse + ProjectsApplicationsMapResponse + ProjectsIntegrationsMapResponse.
    class ProjectsList < NeonAPI::Object
      # Essential data about the project. Full data is available at the getProject endpoint.
      # @return [Array<ProjectListItem>]
      def projects
        Types.wrap(to_h["projects"], ProjectListItem)
      end

      # A list of project IDs indicating which projects are known to exist, but whose details could...
      # @return [Array<String>, nil]
      def unavailable_project_ids
        self["unavailable_project_ids"]
      end

      # Cursor based pagination is used. The user must pass the cursor as is to the backend.
      # @return [Pagination, nil]
      def pagination
        Types.wrap(to_h["pagination"], Pagination)
      end

      # @return [NeonAPI::Object]
      def applications
        self["applications"]
      end

      # @return [NeonAPI::Object]
      def integrations
        self["integrations"]
      end
    end


    # Generated from the OpenAPI schema `Role`.
    class Role < NeonAPI::Object
      # The ID of the branch to which the role belongs
      # @return [String]
      def branch_id
        self["branch_id"]
      end

      # The role name
      # @return [String]
      def name
        self["name"]
      end

      # The role password
      # @return [String, nil]
      def password
        self["password"]
      end

      # Whether or not the role is system-protected
      # @return [Boolean, nil]
      def protected
        self["protected"]
      end

      # Authentication method configured for this role. Valid options: `password`, `oauth`, `no_login`
      # @return [String, nil]
      def authentication_method
        self["authentication_method"]
      end

      # A timestamp indicating when the role was created
      # @return [String]
      def created_at
        self["created_at"]
      end

      # A timestamp indicating when the role was last updated
      # @return [String]
      def updated_at
        self["updated_at"]
      end
    end


    # Generated from the OpenAPI schema `RoleOperations`.
    class RoleOperations < NeonAPI::Object
      # @return [Role]
      def role
        Types.wrap(to_h["role"], Role)
      end

      # @return [Array<Operation>]
      def operations
        Types.wrap(to_h["operations"], Operation)
      end
    end


    # Generated from the OpenAPI schema `RolePasswordResponse`.
    class RolePasswordResponse < NeonAPI::Object
      # The role password
      # @return [String]
      def password
        self["password"]
      end
    end


    # Generated from the OpenAPI schema `RoleResponse`.
    class RoleResponse < NeonAPI::Object
      # @return [Role]
      def role
        Types.wrap(to_h["role"], Role)
      end
    end


    # Generated from the OpenAPI schema `RolesResponse`.
    class RolesResponse < NeonAPI::Object
      # @return [Array<Role>]
      def roles
        Types.wrap(to_h["roles"], Role)
      end
    end

  end
end
