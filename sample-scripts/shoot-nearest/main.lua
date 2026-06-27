-- License: CC0 1.0 Universal ( http://creativecommons.org/publicdomain/zero/1.0/legalcode )
-- 

local keyutils = dofile("keyutils.lua");
local hitutils = dofile("hitutils.lua");

-- 14�t���[����܂ŗ\������������
local predict_frame = 14;
local aim_frame = 6;
local collision_cost = 1000;

-- debug only
local enable_time_logging = false; -- true�ɂ���Ɩ��t���[���̌o�ߎ��ԂȂǂ̃��O�����
local count = 0;
local item_count = 0;
local fp;
if (enable_time_logging) then
  fp = io.open(os.date("%Y%m%d%H%M%S").."-"..tostring(player_side).."p.txt","w");
  fp:write("elapsed time[sec/frame],hittest count,number of objects\n");
end
--

local function findTargetEnemy(player, enemies)
  local px = player.x;
  local py = player.y;
  local target_enemy = nil;
  local best_score = 999999;
  for i,enemy in ipairs(enemies) do
    -- �����{�X�͓|���Â炢�̂Ŗ������Ƃ��B��������̒���͎ア�̂œ|���ɂ����B
    -- pseudo enemy�͌��蓖�Ă̑Ώۂɂ��Ȃ�
    if (not enemy.isPseudoEnemy) and (not(enemy.isSpirit or enemy.isBoss) or enemy.isActivatedSpirit) then
      local dx = math.abs(enemy.x - px);
      local dy = math.abs(enemy.y - py);
      local score = dx + dy * 0.2;
      if score < best_score then
        best_score = score;
        target_enemy = enemy;
      end
    end
  end
  return target_enemy;
end

local function positionCost(player, dx, dy, target_enemy)
  local cost = 0;
  local cx, cy = 0, 300;
  if target_enemy then
    cx = target_enemy.x;
  end
  if (cx - player.x) * dx <= 0 then
    cost = cost + 0.0001;
  end
  if (cy - player.y) * dy <= 0 then
    cost = cost + 0.0001;
  end
  return cost;
end

-- �L�[����̌��B�㉺���E�ړ��ƐΊp�ړ��A�Ⴂ�ړ������߂�
local function generateCandidates(player, target_enemy)
  local candidates = {};
  local speed_fast = player.speedFast;
  local speed_slow = player.speedSlow;
  local diag = 0.70710678;
  local directions = {
    { keys={"up"},             dx= 0,         dy=-1,        speed=speed_fast, use_shift=false },
    { keys={"right"},          dx= 1,         dy= 0,        speed=speed_fast, use_shift=false },
    { keys={"down"},           dx= 0,         dy= 1,        speed=speed_fast, use_shift=false },
    { keys={"left"},           dx=-1,         dy= 0,        speed=speed_fast, use_shift=false },
    { keys={"up", "right"},    dx= diag,      dy=-diag,     speed=speed_fast, use_shift=false },
    { keys={"down", "right"},  dx= diag,      dy= diag,     speed=speed_fast, use_shift=false },
    { keys={"down", "left"},   dx=-diag,      dy= diag,     speed=speed_fast, use_shift=false },
    { keys={"up", "left"},     dx=-diag,      dy=-diag,     speed=speed_fast, use_shift=false },
    { keys={"up"},             dx= 0,         dy=-1,        speed=speed_slow, use_shift=true },
    { keys={"right"},          dx= 1,         dy= 0,        speed=speed_slow, use_shift=true },
    { keys={"down"},           dx= 0,         dy= 1,        speed=speed_slow, use_shift=true },
    { keys={"left"},           dx=-1,         dy= 0,        speed=speed_slow, use_shift=true },
    { keys={"up", "right"},    dx= diag,      dy=-diag,     speed=speed_slow, use_shift=true },
    { keys={"down", "right"},  dx= diag,      dy= diag,     speed=speed_slow, use_shift=true },
    { keys={"down", "left"},   dx=-diag,      dy= diag,     speed=speed_slow, use_shift=true },
    { keys={"up", "left"},     dx=-diag,      dy=-diag,     speed=speed_slow, use_shift=true },
  };
  -- stop
  table.insert(candidates, {
    vx=0,
    vy=0,
    keys={},
    cost=positionCost(player, 0, 0, target_enemy)
  });
  for i,dir in ipairs(directions) do
    local keys = hitutils.copy(dir.keys);
    if dir.use_shift then
      table.insert(keys, "shift");
    end
    table.insert(candidates, {
      vx= dir.dx * dir.speed,
      vy= dir.dy * dir.speed,
      keys=keys,
      cost=positionCost(player, dir.dx, dir.dy, target_enemy)
    });
  end
  return candidates;
end

local function choice(candidates)
  table.sort(candidates, function(a,b) return a.cost < b.cost end);
  return candidates[1].keys;
end

-- ��ʊO�ɏo�Ȃ��悤�ɍ��W��␳
local function adjustX(x)
  if x < -136 then
    return -136;
  elseif x > 136 then
    return 136
  end
  return x;
end
local function adjustY(y)
  if y < 16 then
    return 16;
  elseif y > 384 then
    return 384
  end
  return y;
end

function calculateHitCost(player, elements, hit_body_for_filter_circle, hit_body_for_filter_rect, candidates, hittest_func)
  local px = player.x;
  local py = player.y;
  local player_hit_body_rect = player.hitBodyRect;
  local player_hit_body_circle = player.hitBodyCircle;
  for idx, elm in ipairs(elements) do
    item_count = item_count + 1; -- debug
    local hit_body = elm.hitBody;
    if hit_body and (hitTest(hit_body_for_filter_circle, hit_body) or hitTest(hit_body_for_filter_rect, hit_body)) then
      local ex = elm.x;
      local ey = elm.y;
      local evx = elm.vx or 0;
      local evy = elm.vy or 0;
      for frame=1,predict_frame do
        hit_body.x = ex + evx * frame;
        hit_body.y = ey + evy * frame;
        for i,c in ipairs(candidates) do
          count = count + 1; -- debug
          player_hit_body_rect.x = adjustX(px + c.vx * frame);
          player_hit_body_rect.y = adjustY(py + c.vy * frame);
          player_hit_body_circle.x = adjustX(px + c.vx * frame);
          player_hit_body_circle.y = adjustY(py + c.vy * frame);
          if hittest_func(player, elm) then
            c.cost = c.cost + collision_cost * (0.82 ^ (frame - 1));
          end
        end
      end
    end
  end
end

local shoot_sequence = coroutine.wrap(function()
  while true do
      coroutine.yield(true);
      coroutine.yield(false);
  end
end);

local function shouldShoot(player, nearest_enemy)
  -- �G�Ǝ��@��X���W�̂��ꂪ16px�ȓ��Ȃ猂�ĂΓ�����C������
  if nearest_enemy and (player.x - nearest_enemy.x)^2 < 16^2 then
    if player.spellPoint > 500000 then -- �|�C���g�؂��Ƃ��܂���
      return false;
    else
      return shoot_sequence();
    end
  end
  return false;
end

local function addAimCost(player, target_enemy, candidates)
  if not target_enemy then
    return;
  end
  local target_future_x = target_enemy.x + (target_enemy.vx or 0) * aim_frame;
  for i,c in ipairs(candidates) do
    local player_future_x = adjustX(player.x + c.vx * aim_frame);
    c.cost = c.cost + math.abs(target_future_x - player_future_x) * 0.01;
  end
end

function main ()
  count = 0; -- debug
  item_count = 0; -- debug
  -- time logging
  local time_start;
  if enable_time_logging then
    time_start = os.clock();
  end

  local my_side = game_sides[player_side];
  local player = my_side.player;
  local nearest_enemy = findTargetEnemy(player, my_side.enemies);

  -- generate candidates
  local candidates = generateCandidates(player, nearest_enemy);
  -- �\������e��G���i�邽�߂̓����蔻��B���̓����蔻��ƏՓ˂��Ȃ����̂ɂ��Ă͋����\�����s��Ȃ�
  local hit_body_for_filter_circle = hitutils.copy(player.hitBodyCircle,fp);
  hit_body_for_filter_circle.radius = 50;
  local hit_body_for_filter_rect = hitutils.copy(player.hitBodyRect,fp);
  hit_body_for_filter_rect.width = 100;
  hit_body_for_filter_rect.height = 100;
  -- hittest
  calculateHitCost(-- player vs enemies
    player,
    my_side.enemies,
    hit_body_for_filter_circle,
    hit_body_for_filter_rect,
    candidates,
    hitutils.playerVsEnemy);
  calculateHitCost(-- player vs bullets
    player,
    my_side.bullets,
    hit_body_for_filter_circle,
    hit_body_for_filter_rect,
    candidates,
    hitutils.playerVsBullet);
  calculateHitCost(-- player vs exAttacks
    player,
    my_side.exAttacks,
    hit_body_for_filter_circle,
    hit_body_for_filter_rect,
    candidates,
    hitutils.playerVsExAttack);
  addAimCost(player, nearest_enemy, candidates);
  -- choice
  local keys_to_send = choice(candidates);
  if shouldShoot(player, nearest_enemy) then
    -- �j��I�ɏ��������Ă��邪�A�ǂ���generateCandidates�Ŗ��t���[���������Ă���̂Ȃ̂�OK
    table.insert(keys_to_send, "z");
  end

  -- send keys
  local keys = keyutils.newstate()
  for i,key in ipairs(keys_to_send) do
    keys[key] = true;
  end
  keyutils.send(keys);
  -- time logging
  if enable_time_logging then
    local time_end = os.clock();
    fp:write(tostring(time_end - time_start)..","..tostring(count)..","..tostring(item_count).."\n");
  end
end
