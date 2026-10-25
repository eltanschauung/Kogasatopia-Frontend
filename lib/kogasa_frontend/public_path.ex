defmodule KogasaFrontend.PublicPath do
  @moduledoc """
  Lexical containment plus no-symlink checks BELOW an operator-trusted root.
  The configured root may itself be an intentional deployment alias. Roots and
  their ancestors must not be writable by untrusted users; lstat is not race-proof
  openat confinement against concurrent filesystem mutation.
  """
  def resolve(root, relative) when is_binary(root) and is_binary(relative) do
    root = Path.expand(root)
    candidate = Path.expand(String.trim_leading(relative, "/"), root)

    with true <- String.valid?(relative) and not String.match?(relative, ~r/[\\\\\x00-\x1f\x7f]/),
         true <- candidate == root or String.starts_with?(candidate, root <> "/"),
         true <- File.dir?(root),
         :ok <- check(root, Path.split(Path.relative_to(candidate, root))) do
      {:ok, candidate}
    else
      _ -> :error
    end
  rescue
    _ -> :error
  end

  def resolve(_, _), do: :error

  defp check(_root, []), do: :ok
  defp check(root, ["." | rest]), do: check(root, rest)

  defp check(root, [segment | rest]) do
    path = Path.join(root, segment)

    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory}} -> check(path, rest)
      {:ok, %File.Stat{type: :regular}} when rest == [] -> :ok
      {:error, :enoent} -> :ok
      _ -> :error
    end
  end
end
