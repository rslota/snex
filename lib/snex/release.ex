defmodule Snex.Release do
  def before_assemble(%Mix.Release{} = rel) do
    build_path = Mix.Project.build_path()
    snex_file_wildcard = Path.join([build_path, "lib", "*", "priv", "snex", "**"])

    link_info =
      for snex_file_path <- Path.wildcard(snex_file_wildcard, match_dot: true),
          File.lstat!(snex_file_path).type == :symlink,
          into: %{} do
        target = File.read_link!(snex_file_path)
        relativized_target = relativize_link(target, Path.dirname(snex_file_path))
        {relative_to_lib(snex_file_path), relativized_target}
      end

    steps =
      Enum.flat_map(rel.steps, fn
        :assemble -> [:assemble, &fix_links(&1, link_info)]
        step -> [step]
      end)

    %{rel | steps: steps}
  end

  defp fix_links(%Mix.Release{} = rel, link_info) do
    for {symlink_path, target} <- link_info,
        [appname | app_relative_path] = Path.split(symlink_path),
        symlink_wildcard = Path.join([rel.path, "lib", "#{appname}-*"] ++ app_relative_path),
        symlink_path <- Path.wildcard(symlink_wildcard, match_dot: true) do
      File.rm!(symlink_path)
      File.ln_s!(target, symlink_path)
    end

    rel
  end

  defp relativize_link(target, path) do
    case Path.type(target) do
      :relative ->
        target

      :absolute ->
        relative_path = relative_to_lib(path)
        relative_target = relative_to_lib(target)
        Path.relative_to(relative_target, relative_path)
    end
  end

  defp relative_to_lib(path), do: path |> Path.split() |> do_relative_to_lib()
  defp do_relative_to_lib(["lib" | [_, "priv", "snex" | _] = path]), do: Path.join(path)
  defp do_relative_to_lib([_dir | rest]), do: do_relative_to_lib(rest)
end
