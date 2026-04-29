%% TOP88 Batch Benchmark Study with Density Filter + Heaviside Projection
% Cases:
%   1) half_mbb / MBB
%   2) tip_loaded_cantilever
%
% Study:
%   nelx x nely = 90 x 30
%   volfrac      = [0.2, 0.4, 0.6]
%   target minimum feature = 0.4 in
%
% Important:
%   The MATLAB filter radius rmin is in element units.
%   With elem_size = 0.033 in, rmin = 0.4 / 0.033 = 12.1212 elements.
%
% Projection formulation:
%   x       : raw OC design variable
%   xTilde  : density-filtered design variable
%   xPhys   : projected physical density used by FE analysis
%
% Outputs:
%   Figure 1: three vertically stacked MBB final topologies
%   Figure 2: three vertically stacked tip-loaded cantilever final topologies
%
% Boundary conditions are aligned with the Python TONN-FFBD code:
%   MBB:
%     - vertical load at upper-left node
%     - x-fixed along left edge
%     - y-fixed at bottom-right node
%   Tip_loaded_cantilever:
%     - left edge fully fixed
%     - vertical load at top-right node

clear; clc; close all;

%% ================= USER STUDY BLOCK =================
nelx = 90;
nely = 30;

volfrac_list = [0.2, 0.4, 0.6];
case_list = {'half_mbb', 'tip_loaded_cantilever'};
case_titles = {'MBB', 'Tip-loaded Cantilever'};

penal = 3.0;
E0 = 1.0;
Emin = 1e-9;
nu = 0.3;

% Length-scale matching
elem_size_in = 0.033;
target_min_feature_in = 0.4;
rmin = target_min_feature_in / elem_size_in;

% Density filter is required for the Heaviside-projection workflow.
ft = 2;

% Smooth Heaviside projection settings.
% eta controls the projection threshold. beta controls steepness.
% Larger beta pushes xPhys closer to 0/1, similar in spirit to the
% final sigmoid-like density sharpening in TONN-FFBD.
use_heaviside_projection = true;
eta = 0.5;
beta0 = 1.0;
beta_max = 32.0;
beta_scale = 2.0;
beta_update_every = 50;

max_iter = 200;
tol_change = 1e-2;
move = 0.2;

save_figures = true;
out_dir = fullfile(pwd, 'top88_batch_outputs_heaviside');
if save_figures && ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
%% ====================================================

fprintf('\n============================================================\n');
fprintf('TOP88 Batch Benchmark Study: Density Filter + Heaviside\n');
fprintf('Mesh                  : %d x %d\n', nelx, nely);
fprintf('Volume fractions      : [%s]\n', num2str(volfrac_list));
fprintf('SIMP penal            : %.3f\n', penal);
fprintf('Filter type           : ft = %d density filter\n', ft);
fprintf('Element size          : %.6g in\n', elem_size_in);
fprintf('Target min feature    : %.6g in\n', target_min_feature_in);
fprintf('Equivalent rmin       : %.6g elements\n', rmin);
fprintf('Heaviside projection  : %d\n', use_heaviside_projection);
fprintf('Projection eta        : %.6g\n', eta);
fprintf('Projection beta       : %.6g -> %.6g, scale %.3g every %d iterations\n', ...
        beta0, beta_max, beta_scale, beta_update_every);
fprintf('============================================================\n\n');

all_results = struct();

for icase = 1:numel(case_list)
    case_name = case_list{icase};
    case_title = case_titles{icase};

    fig = figure('Name', ['TOP88 Final Topologies - ' case_title], ...
                 'NumberTitle', 'off', 'Color', 'w');
    tiledlayout(numel(volfrac_list), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    for ivf = 1:numel(volfrac_list)
        volfrac = volfrac_list(ivf);

        fprintf('\nRunning TOP88 | Case = %s | VF = %.2f\n', case_name, volfrac);

        result = top88_run_case_batch(case_name, nelx, nely, volfrac, penal, ...
                                      rmin, ft, max_iter, tol_change, move, ...
                                      E0, Emin, nu, ...
                                      use_heaviside_projection, eta, beta0, ...
                                      beta_max, beta_scale, beta_update_every);

        all_results(icase, ivf).case_name = case_name;
        all_results(icase, ivf).volfrac = volfrac;
        all_results(icase, ivf).result = result;

        nexttile;
        imagesc([0 nelx], [0 nely], 1.0 - result.xPhys);
        set(gca, 'YDir', 'normal');
        colormap(gray);
        caxis([0 1]);
        axis equal tight off;
        title(sprintf('%s | VF = %.1f | C = %.6g | beta = %.3g | iter = %d', ...
              case_title, volfrac, result.final_compliance, result.final_beta, result.iter), ...
              'Interpreter', 'none', 'FontWeight', 'normal');
    end

    sgtitle(sprintf('TOP88 Benchmark: %s | %dx%d | density filter + Heaviside | rmin = %.3f', ...
            case_title, nelx, nely, rmin), ...
            'Interpreter', 'none', 'FontWeight', 'bold');

    if save_figures
        safe_name = lower(strrep(case_title, ' ', '_'));
        safe_name = strrep(safe_name, '-', '_');
        exportgraphics(fig, fullfile(out_dir, ['TOP88_' safe_name '_VF_study_heaviside.png']), 'Resolution', 300);
        savefig(fig, fullfile(out_dir, ['TOP88_' safe_name '_VF_study_heaviside.fig']));
    end
end

fprintf('\n================ FINAL SUMMARY ================\n');
for icase = 1:numel(case_list)
    for ivf = 1:numel(volfrac_list)
        r = all_results(icase, ivf).result;
        fprintf('TOP88 | %-24s | VF target = %.2f | VF final = %.6f | C_final = %.8g | beta_final = %.4g | iter = %d\n', ...
            all_results(icase, ivf).case_name, ...
            all_results(icase, ivf).volfrac, ...
            r.vol_hist(end), ...
            r.final_compliance, ...
            r.final_beta, ...
            r.iter);
    end
end
fprintf('================================================\n');

if save_figures
    fprintf('\nSaved figures to:\n%s\n', out_dir);
end

%% ========================================================================
%% Local functions
%% ========================================================================

function results = top88_run_case_batch(case_name, nelx, nely, volfrac, penal, ...
                                        rmin, ft, max_iter, tol_change, move, ...
                                        E0, Emin, nu, ...
                                        use_heaviside_projection, eta, beta0, ...
                                        beta_max, beta_scale, beta_update_every)
% TOP88-like OC solver for one case and one volume fraction.
% This version uses density filtering followed by smooth Heaviside projection.

%% Element stiffness matrix from TOP88
A11 = [12  3 -6 -3;  3 12  3  0; -6  3 12 -3; -3  0 -3 12];
A12 = [-6 -3  0  3; -3 -6 -3 -6;  0 -3 -6  3;  3 -6  3 -6];
B11 = [-4  3 -2  9;  3 -4 -9  4; -2 -9 -4 -3;  9  4 -3 -4];
B12 = [ 2 -3  4 -9; -3  2  9 -2;  4  9  2  3; -9 -2  3  2];
KE = 1 / (1 - nu^2) / 24 * ([A11 A12; A12' A11] + nu * [B11 B12; B12' B11]);

%% Mesh and DOF numbering
nnodes  = (nelx + 1) * (nely + 1);
nodenrs = reshape(1:nnodes, nely + 1, nelx + 1);
edofVec = reshape(2 * nodenrs(1:end-1, 1:end-1) + 1, nelx * nely, 1);
edofMat = repmat(edofVec, 1, 8) + repmat([0 1 2*nely+[2 3 0 1] -2 -1], nelx*nely, 1);
iK = reshape(kron(edofMat, ones(8, 1))', 64 * nelx * nely, 1);
jK = reshape(kron(edofMat, ones(1, 8))', 64 * nelx * nely, 1);

%% Loads and supports
[F, fixeddofs, case_label] = define_benchmark_case(case_name, nelx, nely, nodenrs);
print_bc_summary(case_label, nelx, nely, F, fixeddofs, nodenrs);
U = zeros(2 * nnodes, 1);
alldofs = (1:2 * nnodes)';
freedofs = setdiff(alldofs, fixeddofs);

%% Filter assembly
nfilter = nelx * nely * (2 * (ceil(rmin) - 1) + 1)^2;
iH = zeros(nfilter, 1);
jH = zeros(nfilter, 1);
sH = zeros(nfilter, 1);
k = 0;
for i1 = 1:nelx
    for j1 = 1:nely
        e1 = (i1 - 1) * nely + j1;
        for i2 = max(i1 - (ceil(rmin) - 1), 1):min(i1 + (ceil(rmin) - 1), nelx)
            for j2 = max(j1 - (ceil(rmin) - 1), 1):min(j1 + (ceil(rmin) - 1), nely)
                e2 = (i2 - 1) * nely + j2;
                k = k + 1;
                iH(k) = e1;
                jH(k) = e2;
                sH(k) = max(0, rmin - sqrt((i1 - i2)^2 + (j1 - j2)^2));
            end
        end
    end
end
H = sparse(iH(1:k), jH(1:k), sH(1:k));
Hs = sum(H, 2);

%% Initialization
x = volfrac * ones(nely, nelx);
xTilde = reshape((H * x(:)) ./ Hs, nely, nelx);
beta = beta0;
[xPhys, ~] = apply_heaviside_projection(xTilde, beta, eta, use_heaviside_projection);
change = 1.0;
loop = 0;

c_hist = zeros(max_iter, 1);
vol_hist = zeros(max_iter, 1);
chg_hist = zeros(max_iter, 1);
beta_hist = zeros(max_iter, 1);

%% Optimization loop
while change > tol_change && loop < max_iter
    loop = loop + 1;

    % FE analysis using projected physical density xPhys
    sK = reshape(KE(:) * (Emin + xPhys(:)'.^penal * (E0 - Emin)), ...
                 64 * nelx * nely, 1);
    K = sparse(iK, jK, sK);
    K = (K + K') / 2;

    U(freedofs) = K(freedofs, freedofs) \ F(freedofs);
    U(fixeddofs) = 0;

    ce = reshape(sum((U(edofMat) * KE) .* U(edofMat), 2), nely, nelx);
    c = sum(sum((Emin + xPhys.^penal * (E0 - Emin)) .* ce));

    % Sensitivities with respect to projected physical density xPhys
    dc = -penal * (E0 - Emin) * xPhys.^(penal - 1) .* ce;
    dv = ones(nely, nelx);

    % Chain rule through Heaviside projection and density filter.
    % xTilde = H*x/Hs, xPhys = Hbeta(xTilde).
    % Therefore d(.)/dx = H' * ((d(.)/dxPhys .* dHbeta/dxTilde)./Hs).
    if ft ~= 2
        error('This Heaviside-projection script is intended to use ft = 2 density filtering.');
    end

    [~, dHdxTilde] = apply_heaviside_projection(xTilde, beta, eta, use_heaviside_projection);
    dc(:) = H' * ((dc(:) .* dHdxTilde(:)) ./ Hs);
    dv(:) = H' * ((dv(:) .* dHdxTilde(:)) ./ Hs);

    % OC update on raw variable x, with volume checked using projected xPhys.
    l1 = 0;
    l2 = 1e9;
    while (l2 - l1) / max(1e-12, l1 + l2) > 1e-3
        lmid = 0.5 * (l2 + l1);
        xnew = max(0, max(x - move, min(1, min(x + move, ...
               x .* sqrt(max(1e-30, -dc ./ dv / lmid))))));

        xTildeNew = reshape((H * xnew(:)) ./ Hs, nely, nelx);
        xPhysNew = apply_heaviside_projection(xTildeNew, beta, eta, use_heaviside_projection);

        if sum(xPhysNew(:)) > volfrac * nelx * nely
            l1 = lmid;
        else
            l2 = lmid;
        end
    end

    change = max(abs(xnew(:) - x(:)));
    x = xnew;
    xTilde = xTildeNew;
    xPhys = xPhysNew;

    c_hist(loop) = c;
    vol_hist(loop) = mean(xPhys(:));
    chg_hist(loop) = change;
    beta_hist(loop) = beta;

    fprintf('  Case:%s It.:%4d Obj.:%12.5f VolFrac:%8.5f ch.:%8.5f beta:%6.2f\n', ...
            case_label, loop, c, mean(xPhys(:)), change, beta);

    % Beta continuation. This is intentionally simple and explicit.
    if use_heaviside_projection && mod(loop, beta_update_every) == 0 && beta < beta_max
        beta = min(beta_max, beta * beta_scale);
        xTilde = reshape((H * x(:)) ./ Hs, nely, nelx);
        xPhys = apply_heaviside_projection(xTilde, beta, eta, use_heaviside_projection);
        fprintf('    Increased Heaviside beta to %.4g\n', beta);
    end
end

% Reanalyze the final plotted physical density so the reported compliance
% corresponds exactly to results.xPhys.
[final_compliance, final_U, final_ce] = compute_compliance_from_density( ...
    xPhys, KE, edofMat, iK, jK, F, freedofs, fixeddofs, nnodes, E0, Emin, penal);

results.x = x;
results.xTilde = xTilde;
results.xPhys = xPhys;
results.U = final_U;
results.iter = loop;
results.c_hist = c_hist(1:loop);
results.vol_hist = vol_hist(1:loop);
results.chg_hist = chg_hist(1:loop);
results.beta_hist = beta_hist(1:loop);
results.case_name = case_label;
results.final_compliance = final_compliance;
results.final_ce = final_ce;
results.final_beta = beta;
results.projection_eta = eta;
results.use_heaviside_projection = use_heaviside_projection;
end

function [xPhys, dHdx] = apply_heaviside_projection(xTilde, beta, eta, use_projection)
% Smooth Heaviside projection after density filtering.
%
%   xPhys = [tanh(beta*eta) + tanh(beta*(xTilde - eta))] /
%           [tanh(beta*eta) + tanh(beta*(1 - eta))]
%
% dHdx is the local derivative dxPhys/dxTilde.

if ~use_projection
    xPhys = xTilde;
    dHdx = ones(size(xTilde));
    return;
end

denom = tanh(beta * eta) + tanh(beta * (1.0 - eta));
xPhys = (tanh(beta * eta) + tanh(beta * (xTilde - eta))) ./ denom;
dHdx = beta * (1.0 - tanh(beta * (xTilde - eta)).^2) ./ denom;

% Guard against tiny numerical overshoot outside [0, 1].
xPhys = min(1.0, max(0.0, xPhys));
end

function [c, U, ce] = compute_compliance_from_density(xPhys, KE, edofMat, iK, jK, ...
                                                       F, freedofs, fixeddofs, ...
                                                       nnodes, E0, Emin, penal)
% Compliance reanalysis for a supplied physical density field.
% This is the exact same FE/compliance definition used inside the OC loop:
%   C = sum_e E_e * u_e' * KE0 * u_e
% where KE0 is the unit-modulus Q4 element stiffness matrix.

nelx = size(xPhys, 2);
nely = size(xPhys, 1);

U = zeros(2 * nnodes, 1);

sK = reshape(KE(:) * (Emin + xPhys(:)'.^penal * (E0 - Emin)), ...
             64 * nelx * nely, 1);
K = sparse(iK, jK, sK);
K = (K + K') / 2;

U(freedofs) = K(freedofs, freedofs) \ F(freedofs);
U(fixeddofs) = 0;

ce = reshape(sum((U(edofMat) * KE) .* U(edofMat), 2), nely, nelx);
c = sum(sum((Emin + xPhys.^penal * (E0 - Emin)) .* ce));
end

function [F, fixeddofs, case_label] = define_benchmark_case(case_name, nelx, nely, nodenrs)
% Load/support definitions explicitly aligned with Python TONN-FFBD.
%
% Python TONN node convention:
%   node_id(ix, iy, nelx) = iy * (nelx + 1) + ix
%   ix = 0      -> left edge
%   ix = nelx   -> right edge
%   iy = 0      -> bottom edge
%   iy = nely   -> top edge
%
% MATLAB TOP88 node lookup used here:
%   node_m(ix, iy) = nodenrs(iy + 1, ix + 1)

nnodes = (nelx + 1) * (nely + 1);
ndof = 2 * nnodes;
F = sparse(ndof, 1);

node_m = @(ix, iy) nodenrs(iy + 1, ix + 1);

switch lower(strtrim(case_name))
    case {'half_mbb', 'mbb', 'half-mbb'}
        % Match TONN-FFBD MBB:
        %   load_node = node_id(0, nely, nelx)
        %   F[2*load_node + 1] = -1.0
        %   fixed x-DOF along ix = 0
        %   fixed y-DOF at ix = nelx, iy = 0

        load_node = node_m(0, nely);          % upper-left node
        F(2 * load_node, 1) = -1.0;          % MATLAB vertical DOF

        left_nodes = nodenrs(:, 1);          % ix = 0, all iy
        x_fixed_left = 2 * left_nodes - 1;   % MATLAB x-DOFs

        bottom_right_node = node_m(nelx, 0); % lower-right node
        y_fixed_bottom_right = 2 * bottom_right_node;

        fixeddofs = sort(unique([x_fixed_left; y_fixed_bottom_right]));
        case_label = 'MBB';

    case {'tip_loaded_cantilever', 'tip_cantilever', 'cantilever_tip'}
        % Match TONN-FFBD Tip_loaded_cantilever:
        %   load_node = node_id(nelx, nely, nelx)
        %   F[2*load_node + 1] = -1.0
        %   fixed both x- and y-DOFs along ix = 0

        left_nodes = nodenrs(:, 1);          % ix = 0, all iy
        fixeddofs = sort(unique([2 * left_nodes - 1; 2 * left_nodes]));

        load_node = node_m(nelx, nely);      % upper-right node
        F(2 * load_node, 1) = -1.0;          % MATLAB vertical DOF

        case_label = 'Tip_loaded_cantilever';

    otherwise
        error(['Unknown case_name: ', case_name, '. This batch script supports ', ...
               '''MBB'' and ''Tip_loaded_cantilever''.']);
end
end

function print_bc_summary(case_label, nelx, nely, F, fixeddofs, nodenrs)
% Prints a compact boundary/load verification for each run.

[load_dofs, ~, load_vals] = find(F);

fprintf('  BC/load verification for %s:\n', case_label);
for k = 1:numel(load_dofs)
    dof = load_dofs(k);
    [ix, iy, comp] = dof_to_ixiy_component(dof, nodenrs);
    fprintf('    Load:  ix = %d, iy = %d, component = %s, value = %.3g\n', ...
        ix, iy, comp, load_vals(k));
end

num_x_fixed_left = 0;
num_y_fixed_left = 0;
has_bottom_right_y = false;

for k = 1:numel(fixeddofs)
    dof = fixeddofs(k);
    [ix, iy, comp] = dof_to_ixiy_component(dof, nodenrs);

    if ix == 0 && strcmp(comp, 'ux')
        num_x_fixed_left = num_x_fixed_left + 1;
    end

    if ix == 0 && strcmp(comp, 'uy')
        num_y_fixed_left = num_y_fixed_left + 1;
    end

    if ix == nelx && iy == 0 && strcmp(comp, 'uy')
        has_bottom_right_y = true;
    end
end

fprintf('    Fixed ux on left edge count : %d of %d\n', num_x_fixed_left, nely + 1);
fprintf('    Fixed uy on left edge count : %d of %d\n', num_y_fixed_left, nely + 1);
fprintf('    Fixed uy at bottom-right    : %d\n', has_bottom_right_y);
end

function [ix, iy, comp] = dof_to_ixiy_component(dof, nodenrs)
% Converts a MATLAB 1-based DOF number back to physical grid coordinates.
% ix and iy are returned in the same 0-based convention used by TONN-FFBD.

if mod(dof, 2) == 1
    node = (dof + 1) / 2;
    comp = 'ux';
else
    node = dof / 2;
    comp = 'uy';
end

[row, col] = find(nodenrs == node, 1);
iy = row - 1;
ix = col - 1;
end
