import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ultimate_team_manager/config/theme/app_colors.dart';
import 'package:ultimate_team_manager/domain/entities/player.dart';
import 'package:ultimate_team_manager/presentation/providers/coins_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/market_provider.dart';
import 'package:ultimate_team_manager/presentation/providers/squad_provider.dart';
import 'package:ultimate_team_manager/presentation/widgets/coins_chip.dart';
import 'package:ultimate_team_manager/presentation/widgets/player_list_row.dart';

/// Mercado (RF4): comprar y vender jugadores. Arriba búsqueda, filtro por
/// posición y orden; luego el selector Comprar|Vender; abajo la lista.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // Diálogo de confirmación de compra/venta con el resumen del jugador.
  Future<void> _confirmTransaction(Player player, MarketMode mode) async {
    final coins = ref.read(coinsProvider);
    final buying = mode == MarketMode.buy;
    final canAfford = !buying || coins >= player.price;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.carbon,
        title: Text(
          buying ? 'Comprar jugador' : 'Vender jugador',
          style: const TextStyle(color: AppColors.texto, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayerListRow(
              player: player,
              subtitle: player.position.group.displayLabel,
              trailing: _PriceTag(price: player.price),
            ),
            if (!canAfford)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Monedas insuficientes.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.gris)),
          ),
          FilledButton(
            onPressed:
                canAfford ? () => Navigator.of(context).pop(true) : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pildora,
              foregroundColor: AppColors.fondo,
              disabledBackgroundColor:
                  AppColors.pildora.withValues(alpha: 0.35),
            ),
            child: Text(buying ? 'Comprar' : 'Vender'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final controller = ref.read(marketControllerProvider.notifier);
    if (buying) {
      final ok = controller.buy(player);
      _showSnack(ok
          ? '${player.name} se unió a tu banca'
          : 'Monedas insuficientes');
    } else {
      controller.sell(player);
      _showSnack('${player.name} vendido por ${player.price} monedas');
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketControllerProvider);
    final squad = ref.watch(squadControllerProvider);
    final players = market.visiblePlayers(squad);

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Encabezado: volver, título y monedas.
              Row(
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: AppColors.texto),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Mercado',
                      style: TextStyle(
                        color: AppColors.texto,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const CoinsChip(),
                ],
              ),
              const SizedBox(height: 12),
              // Búsqueda por nombre.
              TextField(
                controller: _searchCtrl,
                onChanged: (q) =>
                    ref.read(marketControllerProvider.notifier).setQuery(q),
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  labelText: 'Buscar jugador',
                  labelStyle: const TextStyle(color: AppColors.gris),
                  helperText: 'Desde 4 letras también se busca en línea',
                  helperStyle:
                      const TextStyle(color: AppColors.gris, fontSize: 11),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.gris),
                  filled: true,
                  fillColor: AppColors.carbon,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.verde),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Filtro por posición + orden.
              Row(
                children: [
                  Expanded(
                    child: _DarkDropdown<PlayerPositionGroup?>(
                      label: 'Posición',
                      value: market.positionFilter,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Todas')),
                        ...PlayerPositionGroup.values.map(
                          (g) => DropdownMenuItem(
                              value: g, child: Text(g.displayLabel)),
                        ),
                      ],
                      onChanged: (g) => ref
                          .read(marketControllerProvider.notifier)
                          .setPositionFilter(g),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DarkDropdown<MarketSort>(
                      label: 'Ordenar por',
                      value: market.sort,
                      items: MarketSort.values
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.displayLabel)))
                          .toList(),
                      onChanged: (s) {
                        if (s != null) {
                          ref
                              .read(marketControllerProvider.notifier)
                              .setSort(s);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Comprar | Vender.
              SegmentedButton<MarketMode>(
                segments: const [
                  ButtonSegment(
                    value: MarketMode.buy,
                    label: Text('Comprar'),
                    icon: Icon(Icons.shopping_cart_outlined),
                  ),
                  ButtonSegment(
                    value: MarketMode.sell,
                    label: Text('Vender'),
                    icon: Icon(Icons.sell_outlined),
                  ),
                ],
                selected: {market.mode},
                onSelectionChanged: (modes) => ref
                    .read(marketControllerProvider.notifier)
                    .setMode(modes.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.verde2
                        : AppColors.carbon,
                  ),
                  foregroundColor:
                      const WidgetStatePropertyAll(AppColors.texto),
                  side: const WidgetStatePropertyAll(
                      BorderSide(color: AppColors.borde)),
                ),
              ),
              const SizedBox(height: 8),
              // Lista de jugadores (con estados de carga/error/vacío).
              Expanded(child: _buildList(market, players)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(MarketState market, List<Player> players) {
    if (market.isLoading && market.listings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verde),
      );
    }
    if (market.errorMessage != null && market.listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              market.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gris),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref
                  .read(marketControllerProvider.notifier)
                  .loadListings(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.verde2,
                foregroundColor: AppColors.texto,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (players.isEmpty) {
      return Center(
        child: Text(
          market.mode == MarketMode.buy
              ? 'Sin resultados. Prueba otra búsqueda o filtro.'
              : 'No tienes suplentes para vender.\n(Los titulares no se pueden vender.)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gris, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final p = players[i];
        return PlayerListRow(
          player: p,
          subtitle: p.position.group.displayLabel,
          trailing: _PriceTag(price: p.price),
          onTap: () => _confirmTransaction(p, market.mode),
        );
      },
    );
  }
}

/// Precio en monedas, a la derecha de cada fila.
class _PriceTag extends StatelessWidget {
  final int price;
  const _PriceTag({required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on, color: AppColors.pildora, size: 15),
        const SizedBox(width: 3),
        Text(
          '$price',
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Dropdown con la estética oscura del proyecto.
class _DarkDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DarkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppColors.carbon,
      style: const TextStyle(color: AppColors.texto, fontSize: 13),
      iconEnabledColor: AppColors.gris,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.gris, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: AppColors.carbon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.verde),
        ),
      ),
    );
  }
}
