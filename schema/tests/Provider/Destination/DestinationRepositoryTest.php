<?php

namespace Tests\Provider\Destination;

use Ivoz\Provider\Domain\Model\Destination\Destination;
use Ivoz\Provider\Domain\Model\Destination\DestinationRepository;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;
use Tests\DbIntegrationTestHelperTrait;

class DestinationRepositoryTest extends KernelTestCase
{
    use DbIntegrationTestHelperTrait;

    /**
     * @test
     */
    public function test_runner()
    {
        $this->its_instantiable();
        $this->it_returns_prefixes_indexed_by_prefix();
    }

    public function its_instantiable()
    {
        /** @var DestinationRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Destination::class);

        $this->assertInstanceOf(
            DestinationRepository::class,
            $repository
        );
    }

    public function it_returns_prefixes_indexed_by_prefix()
    {
        /** @var DestinationRepository $repository */
        $repository = $this
            ->em
            ->getRepository(Destination::class);

        $prefixes = $repository->getPrefixArrayByBrandId(1);

        $this->assertNotEmpty($prefixes);
        foreach ($prefixes as $prefix => $id) {
            $this->assertIsInt($id);
        }
    }
}
