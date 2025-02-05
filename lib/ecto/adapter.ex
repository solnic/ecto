defmodule Ecto.Adapter do
  @moduledoc """
  This module specifies the adapter API that an adapter is required to
  implement.
  """

  use Behaviour

  @type t :: module
  @type query_meta :: map
  @type model_meta :: %{source: {prefix :: binary, table :: binary}, model: atom, context: term}
  @type fields :: Keyword.t
  @type filters :: Keyword.t
  @type constraints :: Keyword.t
  @type returning :: [atom]
  @type prepared :: term
  @type preprocess :: (field :: Macro.t, value :: term, context :: term -> term)
  @type autogenerate_id :: {field :: atom, type :: :id | :binary_id, value :: term} | nil

  @typep repo :: Ecto.Repo.t
  @typep options :: Keyword.t

  @doc """
  The callback invoked in case the adapter needs to inject code.
  """
  defmacrocallback __before_compile__(Macro.Env.t) :: Macro.t

  ## Types

  @doc """
  Called for every known Ecto type when loading data from the adapter.

  This allows developers to properly translate values coming from
  the adapters into Ecto ones. For example, if the database does not
  support booleans but instead returns 0 and 1 for them, you could
  add:

      def load(:boolean, 0), do: {:ok, false}
      def load(:boolean, 1), do: {:ok, true}
      def load(type, value), do: Ecto.Type.load(type, value, &load/2)

  Notice that `Ecto.Type.load/3` provides a default implementation
  which also expects the current `load/2` for handling recursive
  types like arrays and embeds.

  Finally, notice all adapters are required to implement a clause
  for :binary_id types, since they are adapter specific. If your
  adapter does not provide binary ids, you may simply use Ecto.UUID:

      def load(:binary_id, value), do: load(Ecto.UUID, value)
      def load(type, value), do: Ecto.Type.load(type, value, &load/2)

  """
  defcallback load(Ecto.Type.t, term) :: {:ok, term} | :error

  @doc """
  Called for every known Ecto type when dumping data to the adapter.

  This allows developers to properly translate values coming from
  the Ecto into adapter ones. For example, if the database does not
  support booleans but instead returns 0 and 1 for them, you could
  add:

      def dump(:boolean, false), do: {:ok, 0}
      def dump(:boolean, true), do: {:ok, 1}
      def dump(type, value), do: Ecto.Type.dump(type, value, &dump/2)

  Notice that `Ecto.Type.dump/3` provides a default implementation
  which also expects the current `dump/2` for handling recursive
  types like arrays and embeds.

  Finally, notice all adapters are required to implement a clause
  for :binary_id types, since they are adapter specific. If your
  adapter does not provide binary ids, you may simply use Ecto.UUID:

      def dump(:binary_id, value), do: dump(Ecto.UUID, value)
      def dump(type, value), do: Ecto.Type.dump(type, value, &dump/2)

  """
  defcallback dump(Ecto.Type.t, term) :: {:ok, term} | :error

  @doc """
  Called every time an id is needed for an embedded model.

  It receives the `Ecto.Embedded` struct.
  """
  defcallback embed_id(Ecto.Embedded.t) :: String.t

  @doc """
  Starts any connection pooling or supervision and return `{:ok, pid}`.

  Returns `{:error, {:already_started, pid}}` if the repo already
  started or `{:error, term}` in case anything else goes wrong.

  ## Adapter start

  Because some Ecto tasks like migration may run without starting
  the parent application, it is recommended that start_link in
  adapters make sure the adapter application is started by calling
  `Application.ensure_all_started/1`.
  """
  defcallback start_link(repo, options) ::
              {:ok, pid} | {:error, {:already_started, pid}} | {:error, term}

  @doc """
  Shuts down the repository represented by the given pid.

  This callback must be called by the process that called
  `start_link/2`. Therefore, it is useful for scripts.
  """
  defcallback stop(pid, timeout) :: :ok

  @doc """
  Commands invoked to prepare a query for `all`, `update_all` and `delete_all`.

  The returned result is given to `execute/6`.
  """
  defcallback prepare(:all | :update_all | :delete_all, query :: Ecto.Query.t) ::
              {:cache, prepared} | {:nocache, prepared}

  @doc """
  Executes a previously prepared query.

  It must return a tuple containing the number of entries and
  the result set as a list of lists. The result set may also be
  `nil` if a particular operation does not support them.

  The `meta` field is a map containing some of the fields found
  in the `Ecto.Query` struct.

  It receives a preprocess function that should be invoked for each
  selected field in the query result in order to convert them to the
  expected Ecto type. The `preprocess` function will be nil if no
  result set is expected from the query.
  """
  defcallback execute(repo, query_meta :: map, prepared, params :: list(), preprocess | nil, options) ::
              {integer, [[term]] | nil} | no_return

  @doc """
  Inserts a single new model in the data store.

  ## Autogenerate

  The `autogenerate_id` tells if there is a primary key to be autogenerated
  and, if so, its name, type and value. The type is `:id` or `:binary_id` and
  the adapter should raise if it cannot handle those types.

  If the value is `nil`, it means no value was supplied by the user and
  the database MUST return a new one.

  `autogenerate_id` also allows drivers to detect if a value was assigned
  to a primary key that does not support assignment. In this case, `value`
  will be a non `nil` value.
  """
  defcallback insert(repo, model_meta, fields, autogenerate_id, returning, options) ::
                    {:ok, Keyword.t} | {:invalid, constraints} | no_return

  @doc """
  Updates a single model with the given filters.

  While `filters` can be any record column, it is expected that
  at least the primary key (or any other key that uniquely
  identifies an existing record) be given as a filter. Therefore,
  in case there is no record matching the given filters,
  `{:error, :stale}` is returned.

  ## Autogenerate

  The `autogenerate_id` tells if there is an autogenerated primary key and
  if so, its name type and value. The type is `:id` or `:binary_id` and
  the adapter should raise if it cannot handle those types.

  If the value is `nil`, it means there is no autogenerate primary key.

  `autogenerate_id` also allows drivers to detect if a value was assigned
  to a primary key that does not support assignment. In this case, `value`
  will be a non `nil` value.
  """
  defcallback update(repo, model_meta, fields, filters, autogenerate_id, returning, options) ::
                    {:ok, Keyword.t} | {:invalid, constraints} |
                    {:error, :stale} | no_return

  @doc """
  Deletes a single model with the given filters.

  While `filters` can be any record column, it is expected that
  at least the primary key (or any other key that uniquely
  identifies an existing record) be given as a filter. Therefore,
  in case there is no record matching the given filters,
  `{:error, :stale}` is returned.

  ## Autogenerate

  The `autogenerate_id` tells if there is an autogenerated primary key and
  if so, its name type and value. The type is `:id` or `:binary_id` and
  the adapter should raise if it cannot handle those types.

  If the value is `nil`, it means there is no autogenerate primary key.
  """
  defcallback delete(repo, model_meta, filters, autogenerate_id, options) ::
                     {:ok, Keyword.t} | {:invalid, constraints} |
                     {:error, :stale} | no_return
end
