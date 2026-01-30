import { useState } from 'react';
import { Button, Dropdown, Icon, Section, Stack } from 'tgui-core/components';
import { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type RagecageData = {
  activeDuel?: RagecageDuel;
  duelTeams: RagecageTeam[];
  trioTeams: RagecageTeam[];
  joinRequestCooldown: BooleanLike;
  duelSigned: BooleanLike;
  trioSigned: BooleanLike;
  arenaTypes: string[];
};

type RagecageDuel = {
  firstTeam: RagecageTeam;
  secondTeam: RagecageTeam;
};

type RagecageTeam = {
  members: DuelMember[];
  canJoin: BooleanLike;
  group?: string;
  arenaType: string;
};

type DuelMember = {
  name: string;
  dead: BooleanLike;
  owner: BooleanLike;
};

type DuelTeamProps = {
  team: RagecageTeam;
  trio?: boolean;
};

export function DuelTeam(props: DuelTeamProps) {
  const { team, trio } = props;
  const { data, act } = useBackend<RagecageData>();
  return (
    <Section
      buttons={
        !!team.canJoin && (
          <Button
            disabled={data.joinRequestCooldown}
            onClick={() => act('request_join', { ref: team.group })}
          >
            Join Team
          </Button>
        )
      }
      title={`${team.members.find((x) => x.owner)?.name}'s Team - ${team.arenaType}`}
    >
      <Stack fill vertical zebra>
        {team.members.map((member) => (
          <Stack.Item key={member.name} textColor={!!member.dead && 'dimgrey'}>
            {member.name}
            {trio && !!member.owner && (
              <Icon
                name="crown"
                color="gold"
                mr={2}
                ml={1}
                style={{ float: 'right' }}
              />
            )}
          </Stack.Item>
        ))}
      </Stack>
    </Section>
  );
}

export function RagecageConsole() {
  const { data, act } = useBackend<RagecageData>();
  const {
    activeDuel,
    duelTeams,
    trioTeams,
    duelSigned,
    trioSigned,
    arenaTypes,
  } = data;
  const [joinRandom, setJoinRandom] = useState(true);
  const [chosenArena, setChosenArena] = useState(
    arenaTypes[arenaTypes.length - 1],
  );

  return (
    <Window title="Arena Signup Console" width={900} height={400}>
      <Window.Content>
        {!!activeDuel && (
          <Section title="Active Duel">
            <Stack fill>
              <Stack.Item>
                <DuelTeam team={activeDuel.firstTeam} />
              </Stack.Item>
              <Stack.Item
                style={{ textAlign: 'center', verticalAlign: 'center' }}
              >
                vs
              </Stack.Item>
              <Stack.Item>
                <DuelTeam team={activeDuel.secondTeam} />
              </Stack.Item>
            </Stack>
          </Section>
        )}
        <Stack fill>
          <Stack.Item grow>
            <Section
              title="Duel Participants"
              buttons={
                <Stack>
                  {!duelSigned ? (
                    <Button
                      color="good"
                      onClick={() =>
                        act('duel_signup', { arena_type: chosenArena })
                      }
                    >
                      Sign Up
                    </Button>
                  ) : (
                    <Button color="bad" onClick={() => act('duel_drop')}>
                      Leave Queue
                    </Button>
                  )}
                  <Stack.Item>
                    <Dropdown
                      selected={chosenArena}
                      onSelected={(value) => setChosenArena(value)}
                      options={arenaTypes}
                    />
                  </Stack.Item>
                </Stack>
              }
              fill
            >
              {duelTeams.map((team, i) => (
                <DuelTeam key={i} team={team} />
              ))}
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section
              title="Trio Participants"
              buttons={
                <Stack>
                  <Stack.Item>
                    {!trioSigned ? (
                      <Button
                        color="good"
                        onClick={() =>
                          act('trio_signup', {
                            join_random: joinRandom,
                            arena_type: chosenArena,
                          })
                        }
                      >
                        Sign Up
                      </Button>
                    ) : (
                      <Button color="bad" onClick={() => act('trio_drop')}>
                        Leave Queue
                      </Button>
                    )}
                  </Stack.Item>
                  <Stack.Item>
                    <Button.Checkbox
                      checked={joinRandom}
                      onClick={() => setJoinRandom(!joinRandom)}
                      tooltip="Join other groups when there's enough players to start a fight?"
                    >
                      Join Groups
                    </Button.Checkbox>
                  </Stack.Item>
                </Stack>
              }
              fill
            >
              {trioTeams.map((team, i) => (
                <DuelTeam trio key={i} team={team} />
              ))}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
